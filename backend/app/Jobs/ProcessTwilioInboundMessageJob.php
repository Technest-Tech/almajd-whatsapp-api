<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Enums\DeliveryStatus;
use App\Enums\MessageDirection;
use App\Enums\MessageType;
use App\Models\WhatsappMessage;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class ProcessTwilioInboundMessageJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 5;
    public array $backoff = [10, 30, 60, 120, 300];

    public function __construct(
        private readonly array $payload
    ) {
        $this->onQueue('high');
    }

    /**
     * Process inbound Twilio Sandbox message.
     */
    public function handle(): void
    {
        $messageSid = $this->payload['MessageSid'] ?? null;
        
        if (!$messageSid) {
            Log::warning("Twilio Webhook: No MessageSid found in payload.", ['payload' => $this->payload]);
            return;
        }

        // Avoid duplicate reprocessing
        if (WhatsappMessage::where('wa_message_id', $messageSid)->exists()) {
            Log::info("Twilio Webhook: Duplicate message skipped: {$messageSid}");
            return;
        }

        $fromNumber = $this->payload['From'] ?? '';
        $body       = trim($this->payload['Body'] ?? '');

        $cleanFrom = str_replace('whatsapp:', '', $fromNumber);
        $phoneWithPlus = str_starts_with($cleanFrom, '+') ? $cleanFrom : '+' . $cleanFrom;

        // ── Teacher Confirmation Check ──
        if (in_array($body, ['1', '2'])) {
            $handled = $this->handleTeacherConfirmation($phoneWithPlus, $body);
            if ($handled) {
                Log::info("Teacher confirmation handled from {$phoneWithPlus}: {$body}");
                // Continue processing to also store the message in inbox
            }
        }

        $toNumber   = str_replace('whatsapp:', '', $this->payload['To'] ?? '');
        $fromNumber = $cleanFrom;
        $numMedia   = (int) ($this->payload['NumMedia'] ?? 0);

        // Normalize Media
        $mediaUrl   = null;
        $mediaMime  = null;
        $msgType    = MessageType::Text;

        if ($numMedia > 0) {
            $rawMediaUrl = $this->payload['MediaUrl0'] ?? null;
            $mediaMime   = $this->payload['MediaContentType0'] ?? null;
            
            if ($rawMediaUrl) {
                try {
                    $sid = env('TWILIO_ACCOUNT_SID');
                    $token = env('TWILIO_AUTH_TOKEN');
                    
                    $response = \Illuminate\Support\Facades\Http::withBasicAuth($sid, $token)
                        ->timeout(15)
                        ->get($rawMediaUrl);
                        
                    if ($response->successful()) {
                        $extension = 'bin';
                        if (str_starts_with((string)$mediaMime, 'image/jpeg')) $extension = 'jpeg';
                        elseif (str_starts_with((string)$mediaMime, 'image/png')) $extension = 'png';
                        elseif (str_starts_with((string)$mediaMime, 'audio/')) $extension = 'm4a';
                        elseif (str_starts_with((string)$mediaMime, 'video/mp4')) $extension = 'mp4';
                        elseif (str_starts_with((string)$mediaMime, 'application/pdf')) $extension = 'pdf';
                        
                        $filename = \Illuminate\Support\Str::ulid() . '.' . $extension;
                        $path = 'tickets/inbound/' . $filename;
                        
                        \Illuminate\Support\Facades\Storage::disk('public')->put($path, $response->body());
                        $mediaUrl = url(\Illuminate\Support\Facades\Storage::url($path));
                    } else {
                        Log::error("Failed to download Twilio media", ['status' => $response->status(), 'url' => $rawMediaUrl]);
                        $mediaUrl = $rawMediaUrl;
                    }
                } catch (\Exception $e) {
                    Log::error("Exception downloading Twilio media: " . $e->getMessage());
                    $mediaUrl = $rawMediaUrl;
                }
            }
            
            // Guess type roughly by mime
            if (str_starts_with((string)$mediaMime, 'image/')) {
                $msgType = MessageType::Image;
            } elseif (str_starts_with((string)$mediaMime, 'video/')) {
                $msgType = MessageType::Video;
            } elseif (str_starts_with((string)$mediaMime, 'audio/')) {
                $msgType = MessageType::Audio;
            } else {
                $msgType = MessageType::Document;
            }
        }

        // For templates injected by sandbox API
        if (!empty($this->payload['ContentSid'])) {
             $msgType = MessageType::Template;
        }

        // --- Resolve Guardian and Ticket ---
        $phoneWithPlus = str_starts_with($fromNumber, '+') ? $fromNumber : '+' . $fromNumber;
        $guardian = \App\Models\Guardian::where('phone', $fromNumber)->orWhere('phone', $phoneWithPlus)->first();
        
        $ticket = null;
        if ($guardian) {
            $ticket = \App\Models\Ticket::where('guardian_id', $guardian->id)
                ->whereIn('status', [\App\Enums\TicketStatus::Open, \App\Enums\TicketStatus::Pending])
                ->latest()
                ->first();
                
            if (!$ticket) {
                $ticket = \App\Models\Ticket::create([
                    'ticket_number' => \App\Models\Ticket::generateTicketNumber(),
                    'guardian_id'   => $guardian->id,
                    'status'        => \App\Enums\TicketStatus::Open,
                    'priority'      => \App\Enums\TicketPriority::Normal,
                    'channel'       => 'whatsapp',
                    'subject'       => 'New Inquiry',
                ]);
            } elseif ($ticket->status === \App\Enums\TicketStatus::Pending) {
                $ticket->update(['status' => \App\Enums\TicketStatus::Open]);
            }
        } else {
            // Unregistered contact
            $guardian = \App\Models\Guardian::create([
                'name'  => 'Unknown Contact',
                'phone' => $phoneWithPlus,
            ]);
            
            $ticket = \App\Models\Ticket::create([
                'ticket_number' => \App\Models\Ticket::generateTicketNumber(),
                'guardian_id'   => $guardian->id,
                'status'        => \App\Enums\TicketStatus::Open,
                'priority'      => \App\Enums\TicketPriority::Normal,
                'channel'       => 'whatsapp',
                'subject'       => 'New WhatsApp Inquiry',
            ]);
        }

        // Auto-link student and update guardian name if still 'Unknown Contact'
        if ($guardian->name === 'Unknown Contact') {
            $firstStudent = $guardian->students()->first()
                ?? \App\Models\Student::where('phone', $guardian->phone)->first();
            if ($firstStudent) {
                $guardian->update(['name' => $firstStudent->name]);
                if (!$firstStudent->guardian_id) {
                    $firstStudent->update(['guardian_id' => $guardian->id]);
                }
            }
        }
        if (!$ticket->student_id) {
            $firstStudent = $guardian->students()->first()
                ?? \App\Models\Student::where('phone', $guardian->phone)->first();
            if ($firstStudent) {
                $ticket->update(['student_id' => $firstStudent->id]);
            }
        }

        // Store the final structured message
        // Resolve reply context (when student replies to a specific message on WhatsApp)
        $replyToMessageId = null;
        $originalRepliedSid = $this->payload['OriginalRepliedMessageSid'] ?? null;
        if ($originalRepliedSid) {
            $parentMsg = WhatsappMessage::where('wa_message_id', $originalRepliedSid)->first();
            if ($parentMsg) {
                $replyToMessageId = $parentMsg->id;
            }
        }

        $whatsappMessage = WhatsappMessage::create([
            'wa_message_id'       => $messageSid,
            'ticket_id'           => $ticket->id,
            'direction'           => MessageDirection::Inbound,
            'from_number'         => $phoneWithPlus,
            'to_number'           => $toNumber,
            'message_type'        => $msgType,
            'content'             => $body,
            'media_url'           => $mediaUrl,
            'media_mime_type'     => $mediaMime,
            'delivery_status'     => DeliveryStatus::Delivered,
            'reply_to_message_id' => $replyToMessageId,
            'timestamp'           => now(),
        ]);

        $ticket->update([
            'last_message_preview' => \Illuminate\Support\Str::limit($body ?: 'Media Message', 100),
            'unread_count' => ($ticket->unread_count ?? 0) + 1,
        ]);

        // Create in-app notification for all admins
        $senderName = $ticket->guardian?->name ?? $phoneWithPlus;
        $preview = \Illuminate\Support\Str::limit($body ?: ($msgType->value === 'image' ? '📷 صورة' : ($msgType->value === 'audio' ? '🎵 صوت' : '📄 ملف')), 80);
        \App\Models\AppNotification::notifyAdmins(
            type: 'message',
            title: "رسالة جديدة من {$senderName}",
            body: $preview,
            data: ['ticket_id' => $ticket->id, 'guardian_name' => $senderName],
        );

        Log::info("Inbound Twilio message stored", [
            'id'   => $whatsappMessage->id,
            'from' => $fromNumber,
            'type' => $msgType->value,
        ]);

        // Trigger Event for frontend WebSockets
        event(new \App\Events\TicketMessageCreated($ticket, $whatsappMessage));
    }

    /**
     * Handle teacher confirmation reply (1=yes, 2=no).
     */
    private function handleTeacherConfirmation(string $phone, string $reply): bool
    {
        // Find the most recent awaiting confirmation reminder for this phone
        $reminder = \App\Models\Reminder::where('recipient_phone', $phone)
            ->where('recipient_type', 'teacher')
            ->where('confirmation_status', 'awaiting')
            ->where('status', 'sent')
            ->latest('sent_at')
            ->first();

        if (!$reminder || !$reminder->class_session_id) {
            return false;
        }

        $session = \App\Models\ClassSession::find($reminder->class_session_id);
        if (!$session) return false;

        $phase = $reminder->reminder_phase; // at_start, after, post_end

        if ($reply === '1') {
            $reminder->update(['confirmation_status' => 'confirmed']);

            if ($phase === 'post_end') {
                // Post-end confirmation → class completed
                $session->update([
                    'status' => 'completed',
                    'attendance_status' => 'both_joined',
                ]);
            } else {
                // At start / after start → class is running
                $session->update([
                    'status' => 'running',
                    'attendance_status' => 'teacher_joined',
                ]);
            }
        } else {
            $reminder->update(['confirmation_status' => 'denied']);

            if ($phase === 'post_end') {
                // Teacher says class didn't complete → keep pending for supervisor
                $session->update([
                    'status' => 'pending',
                    'attendance_status' => 'teacher_joined',
                ]);
            } else {
                // Teacher didn't enter class
                $session->update([
                    'attendance_status' => 'no_show',
                ]);
            }
        }

        // Mark other awaiting reminders for same session+phase as resolved
        \App\Models\Reminder::where('class_session_id', $session->id)
            ->where('confirmation_status', 'awaiting')
            ->where('id', '!=', $reminder->id)
            ->where('reminder_phase', $phase)
            ->update(['confirmation_status' => 'no_reply']);

        return true;
    }

    public function failed(\Throwable $e): void
    {
        Log::error('ProcessTwilioInboundMessageJob failed', [
            'error'   => $e->getMessage(),
            'payload' => $this->payload,
        ]);
    }
}
