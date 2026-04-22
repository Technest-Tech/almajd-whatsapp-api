<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Enums\DeliveryStatus;
use App\Enums\MessageDirection;
use App\Enums\MessageType;
use App\Enums\TicketPriority;
use App\Enums\TicketStatus;
use App\Models\AppNotification;
use App\Models\ClassSession;
use App\Models\Guardian;
use App\Models\Reminder;
use App\Models\Student;
use App\Models\Teacher;
use App\Models\Ticket;
use App\Models\WhatsappMessage;
use App\Services\SessionLoadBalancerService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/**
 * Process an inbound WhatsApp message received from the WasenderAPI webhook.
 *
 * Wasender webhook payload structure (messages.received event):
 * {
 *   "event": "messages.received",
 *   "timestamp": 1633456789,
 *   "data": {
 *     "messages": {
 *       "key": {
 *         "id": "3EB0X123456789",
 *         "fromMe": false,
 *         "remoteJid": "201234567890@s.whatsapp.net",
 *         "cleanedSenderPn": "201234567890",
 *         "senderLid": "123456789@lid"
 *       },
 *       "messageBody": "Hello!",
 *       "message": {
 *         "conversation": "Hello!",
 *         "imageMessage": { ... }   // for media
 *       }
 *     }
 *   }
 * }
 */
class ProcessWasenderInboundMessageJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 5;
    public array $backoff = [10, 30, 60, 120, 300];

    public function __construct(
        private array $payload
    ) {
        $this->onQueue('high');
    }

    public function handle(): void
    {
        $event    = $this->payload['event'] ?? '';
        $messages = $this->payload['data']['messages'] ?? [];

        Log::info('WASENDER_WEBHOOK_DUMP', ['payload' => $this->payload]);

        // Detect poll vote events — they arrive either as 'poll.results' or inside 'messages.upsert'
        $isPollVote = $event === 'poll.results' || (
            in_array($event, ['messages.received', 'messages.upsert'], true)
            && isset($messages['message']['pollUpdateMessage'])
        );

        // Route to appropriate handler based on event type
        match (true) {
            $isPollVote                                                       => $this->handlePollVote(),
            in_array($event, ['messages.received', 'messages.upsert'], true) => $this->handleInboundMessage(),
            $event === 'chats.update'                                        => $this->handleChatsUpdate(),
            in_array($event, ['messages.update', 'message.update'], true)    => $this->handleStatusUpdate(),
            default => Log::debug('WasenderAPI webhook: unhandled event', ['event' => $event]),
        };

        // ── NOTE on report confirmation polls ────────────────────────────────
        // Report-confirm polls ("هل هذا هو تقرير الحصة؟") are handled inside
        // handlePollVote() via the isReportConfirmPoll() guard, which checks
        // whether the poll question starts with 'تأكيد_تقرير:'. No extra routing
        // is needed here.
    }


    // ──────────────────────────────────────────────────────────────────────────
    // Poll Vote Handler — teacher taps Yes/No on a session confirmation poll
    // Fully supports the teacher changing their mind (Yes → No or No → Yes)
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * WhatsApp poll votes arrive as messages.upsert with:
     *   message.pollUpdateMessage.pollCreationMessageKey.id  → the original poll's WA message ID
     *   message.pollUpdateMessage.vote.selectedOptions[]     → array of selected option SHA-256 hashes
     *                                                           (empty array = deselected all / abstained)
     *
     * Wasender (as of 2024) may also provide a decoded `selectedOptionNames` array.
     * We check for the decoded names first, then fall back to SHA-256 hash comparison.
     */
    private function handlePollVote(): void
    {
        Log::info('WasenderAPI: Poll vote payload', [
            'payload' => $this->payload,
        ]);

        $event = $this->payload['event'] ?? '';
        $data  = $this->payload['data'] ?? [];

        $pollMsgId     = null;
        $pollQuestion  = null;
        $voterPhone    = null;
        $selectedNames = [];
        $voteValue     = null;

        // ── 1. Parse 'poll.results' format (Current WasenderAPI docs) ──────────
        if ($event === 'poll.results') {
            $pollMsgId    = $data['key']['id'] ?? null;
            $remoteJid    = $data['key']['remoteJid'] ?? '';
            $pollQuestion = $data['pollMsg']['pollCreationMessageV3']['name']
                ?? $data['pollMsg']['pollCreationMessage']['name']
                ?? null;

            $pollResult = $data['pollResult'] ?? [];
            foreach ($pollResult as $option) {
                if (!empty($option['voters'])) {
                    $selectedNames[] = $option['name'];
                    // We extract the first voter's phone (in 1:1 chats it's just the teacher)
                    $voterJid = $option['voters'][0];
                    $voterPhone = preg_replace('/[^0-9]/', '', explode('@', $voterJid)[0] ?? '');
                }
            }

            if (!$voterPhone) {
                $voterPhone = preg_replace('/[^0-9]/', '', explode('@', $remoteJid)[0] ?? '');
            }
        }
        // ── 2. Parse legacy / alternative 'messages.upsert' format ──────────────
        else {
            $rawMsgs  = $data['messages'] ?? [];
            $messages = isset($rawMsgs[0]) ? $rawMsgs[0] : $rawMsgs;

            $key      = $messages['key'] ?? [];
            $pollVote = $messages['message']['pollUpdateMessage'] ?? [];

            $pollMsgId = $pollVote['pollCreationMessageKey']['id'] ?? null;

            $voterRaw = $key['cleanedSenderPn'] ?? $key['cleanedParticipantPn'] ?? $key['participant'] ?? $key['remoteJid'] ?? $data['id'] ?? '';
            $voterPhone = preg_replace('/[^0-9]/', '', explode('@', $voterRaw)[0] ?? '');

            // Fallback SHA-256 resolution
            $selectedHashes = $pollVote['vote']['selectedOptions'] ?? [];
            if (!empty($selectedHashes)) {
                // We'll rely on the DB reminder body below to hash and match options
                $selectedNames = []; // Will be populated after finding reminder
            }
        }

        if ($voterPhone) {
            $voterPhone = str_starts_with($voterPhone, '+') ? $voterPhone : "+{$voterPhone}";
        }

        // ── Early exit: report-confirm polls are NOT session-confirmation polls ──
        // These polls are generated by maybeHandleReportSubmission() and have a
        // question that starts with 'تأكيد_تقرير:'. They must be handled entirely
        // differently (no Reminder row involved), so we intercept them here first.
        if ($pollQuestion && str_starts_with($pollQuestion, 'تأكيد_تقرير:')) {
            // Normalise vote from selectedNames before delegating
            $reportVote = null;
            foreach ($selectedNames as $name) {
                $clean = trim($name);
                if (str_contains($clean, 'نعم') || str_contains(mb_strtolower($clean), 'yes')) {
                    $reportVote = 'yes';
                    break;
                }
                if (str_contains($clean, 'لا') || str_contains(mb_strtolower($clean), 'no')) {
                    $reportVote = 'no';
                    break;
                }
            }
            $this->handleReportConfirmPoll($pollQuestion, $reportVote, $voterPhone);
            return;
        }

        // ── Find the reminder that owns this poll ─────────────────────────────
        // Primary match: most recent teacher reminder with this poll question for this voter.
        // We intentionally do NOT filter by confirmation_status so teachers can change
        // their vote (e.g. YES → NO) and have the session state reverted accordingly.
        // Wasender's /send-message returns an internal numeric msgId which does NOT
        // equal the WhatsApp message key.id that arrives in poll.results webhooks,
        // so matching by question text is the reliable path for teacher polls
        // (each poll question uniquely identifies a session + student).
        $reminder = null;

        if ($pollQuestion && $voterPhone) {

            $reminder = \App\Models\Reminder::where('recipient_phone', $voterPhone)
                ->where('recipient_type', 'teacher')
                ->where('message_body', $pollQuestion)
                ->orderByDesc('sent_at')
                ->first();
        }

        // Fallback: legacy ID-based lookup (only useful if poll_message_id was stored correctly)
        if (!$reminder && $pollMsgId) {
            $reminderQuery = \App\Models\Reminder::where('poll_message_id', $pollMsgId);
            if ($voterPhone) {
                $reminderQuery->where('recipient_phone', $voterPhone);
            }
            $reminder = $reminderQuery->first()
                ?? \App\Models\Reminder::where('poll_message_id', $pollMsgId)->first();
        }

        if (!$reminder || !$reminder->class_session_id) {
            Log::info('WasenderAPI: Poll vote received but no matching reminder found', [
                'poll_msg_id'   => $pollMsgId,
                'poll_question' => $pollQuestion,
                'voter'         => $voterPhone,
            ]);
            return;
        }

        // ── Legacy Format Hash resolution (if names weren't provided directly)
        if ($event !== 'poll.results' && empty($selectedNames)) {
            $dataMsgs = $data['messages'] ?? [];
            $msgPart = isset($dataMsgs[0]) ? $dataMsgs[0] : $dataMsgs;
            $selectedHashes = $msgPart['message']['pollUpdateMessage']['vote']['selectedOptions'] ?? [];
            
            if (!empty($selectedHashes)) {
                $knownOptions = [
                    'نعم، انضم'   => 'yes',
                    'لا، لم ينضم' => 'no',
                ];
                $pollQuestion = $reminder->message_body ?? '';
                foreach ($knownOptions as $optionText => $vote) {
                    $hash = hash('sha256', mb_strtolower($optionText) . "\0" . mb_strtolower($pollQuestion));
                    if (in_array($hash, $selectedHashes, true) ||
                        in_array(base64_encode(hex2bin($hash)), $selectedHashes, true)) {
                        $selectedNames[] = $optionText;
                    }
                }
            }
        }

        // Normalise: is the vote Yes, No, or cleared?
        foreach ($selectedNames as $name) {
            $clean = trim($name);
            if (str_contains($clean, 'نعم') || str_contains($clean, '1') || str_contains(mb_strtolower($clean), 'yes')) {
                $voteValue = 'yes';
                break;
            }
            if (str_contains($clean, 'لا') || str_contains($clean, '2') || str_contains(mb_strtolower($clean), 'no')) {
                $voteValue = 'no';
                break;
            }
        }

        Log::info('WasenderAPI: Poll vote handled successfully', [
            'poll_msg_id'   => $pollMsgId,
            'voter'         => $voterPhone,
            'selected'      => $selectedNames,
            'resolved_vote' => $voteValue,
            'reminder_id'   => $reminder->id,
            'phase'         => $reminder->reminder_phase,
        ]);

        // ── Apply session status change ───────────────────────────────────────
        $session = \App\Models\ClassSession::find($reminder->class_session_id);
        if (!$session || in_array($session->status, ['completed', 'cancelled'], true)) {
            // Allow post_end confirmations even on "completed" — admin may have pre-closed it
            if (!($session && $reminder->reminder_phase === 'post_end')) {
                Log::info('WasenderAPI: Poll vote ignored — session already closed', [
                    'session_id' => $reminder->class_session_id,
                    'status'     => $session?->status,
                ]);
                return;
            }
        }

        $phase = $reminder->reminder_phase;

        if ($voteValue === 'yes') {
            // ── Teacher confirmed: student joined / session completed ──────────
            $reminder->update(['confirmation_status' => 'confirmed']);

            if (in_array($phase, ['post_end', 'post_end_2'], true)) {
                $session->update(['status' => 'completed', 'attendance_status' => 'both_joined']);
                // ── NEW: kick off the report collection flow ──────────────────
                $this->maybeRequestSessionReport($session, $voterPhone);
            } else {
                $session->update(['status' => 'running', 'attendance_status' => 'both_joined']);
            }

            // Cancel superseded pre-class reminders
            \App\Models\Reminder::where('class_session_id', $session->id)
                ->where('status', 'pending')
                ->whereIn('reminder_phase', ['before', 'at_start', 'after'])
                ->update(['status' => 'cancelled', 'failure_reason' => 'Teacher confirmed via poll']);

            // Mark other awaiting reminders as no_reply
            \App\Models\Reminder::where('class_session_id', $session->id)
                ->where('confirmation_status', 'awaiting')
                ->where('id', '!=', $reminder->id)
                ->update(['confirmation_status' => 'no_reply']);

            Log::info('WasenderAPI: Poll YES — session updated', [
                'session_id' => $session->id,
                'new_status' => $session->status,
            ]);

        } elseif ($voteValue === 'no') {
            // ── Teacher denied: student did not join / session not completed ───
            $reminder->update(['confirmation_status' => 'denied']);

            if (in_array($phase, ['post_end', 'post_end_2'], true)) {
                // Post-end denial — session was running but teacher says it's NOT done
                $session->update(['status' => 'running']);
            } else {
                // At-start/after denial — student never joined
                $session->update(['status' => 'pending', 'attendance_status' => 'no_show']);
            }

            Log::info('WasenderAPI: Poll NO — session updated', [
                'session_id' => $session->id,
                'new_status' => $session->status,
            ]);

        } else {
            // Vote cleared / unknown option — log and leave session as-is
            Log::info('WasenderAPI: Poll vote unclear or deselected', [
                'selected'   => $selectedNames,
                'session_id' => $session->id,
            ]);
            $reminder->update(['confirmation_status' => 'awaiting']);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // chats.update → extract inbound messages and process them
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Wasender often delivers inbound messages via "chats.update" instead of
     * "messages.received". The payload structure is:
     *
     * {
     *   "event": "chats.update",
     *   "data": {
     *     "chats": {
     *       "id": "…@lid",
     *       "messages": [
     *         {
     *           "message": {
     *             "key": { "id": "…", "fromMe": false, "remoteJid": "…@lid", "remoteJidAlt": "201…@s.whatsapp.net" },
     *             "message": { "conversation": "reply text" },
     *             "pushName": "Contact Name",
     *             "messageTimestamp": 123456789
     *           }
     *         }
     *       ]
     *     }
     *   }
     * }
     *
     * We transform each inbound message into the same structure that
     * handleInboundMessage() expects (data.messages format) and process it.
     */
    private function handleChatsUpdate(): void
    {
        $chats = $this->payload['data']['chats'] ?? null;
        if (!$chats || empty($chats['messages'])) {
            return;
        }

        foreach ($chats['messages'] as $chatMsg) {
            $msg = $chatMsg['message'] ?? null;
            if (!$msg) continue;

            $key = $msg['key'] ?? [];

            // NOTE: fromMe=true means WE sent this from WhatsApp Business App
            // We process BOTH directions — fromMe=false (inbound) and fromMe=true (outbound)
            $fromMe = $key['fromMe'] ?? false;

            $messageId = $key['id'] ?? null;
            if (!$messageId) continue;

            // Dedup guard
            if (WhatsappMessage::where('wa_message_id', $messageId)->exists()) continue;

            // Extract phone from remoteJidAlt or remoteJid
            $phone = null;
            $remoteJidAlt = $key['remoteJidAlt'] ?? null;
            if ($remoteJidAlt && str_contains($remoteJidAlt, '@s.whatsapp.net')) {
                $phone = preg_replace('/[^0-9]/', '', explode('@', $remoteJidAlt)[0]);
            }
            if (!$phone) {
                $remoteJid = $key['remoteJid'] ?? '';
                if (str_contains($remoteJid, '@s.whatsapp.net')) {
                    $phone = preg_replace('/[^0-9]/', '', explode('@', $remoteJid)[0]);
                }
            }
            if (!$phone) continue;

            // Build a normalised payload matching what handleInboundMessage expects
            $textBody = $msg['message']['conversation']
                ?? $msg['message']['extendedTextMessage']['text']
                ?? '';

            $transformedPayload = [
                'event' => 'messages.received',
                'data'  => [
                    'messages' => [
                        'key' => [
                            'id'              => $messageId,
                            'fromMe'          => $fromMe,
                            'remoteJid'       => $remoteJidAlt ?? $key['remoteJid'] ?? '',
                            'cleanedSenderPn' => $phone,
                        ],
                        'messageBody' => $textBody,
                        'message'     => $msg['message'] ?? [],
                        'pushName'    => $msg['pushName'] ?? '',
                    ],
                ],
            ];

            // Swap payload and process through the standard handler
            $originalPayload = $this->payload;
            $this->payload = $transformedPayload;
            $this->handleInboundMessage();
            $this->payload = $originalPayload;
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Inbound Message Handler
    // ──────────────────────────────────────────────────────────────────────────

    private function handleInboundMessage(): void
    {
        $messages = $this->payload['data']['messages'] ?? null;

        if (!$messages) {
            Log::warning('WasenderAPI: No messages data in payload', ['payload' => $this->payload]);
            return;
        }

        $key    = $messages['key'] ?? [];
        $fromMe = (bool) ($key['fromMe'] ?? false);

        // fromMe=true  → message WE sent from WhatsApp Business App → store as outbound
        // fromMe=false → message customer sent → store as inbound
        $direction = $fromMe ? MessageDirection::Outbound : MessageDirection::Inbound;

        $messageId = $key['id'] ?? null;
        if (!$messageId) {
            Log::warning('WasenderAPI: No message ID in key', ['key' => $key]);
            return;
        }

        // Deduplication guard
        if (WhatsappMessage::where('wa_message_id', $messageId)->exists()) {
            Log::info("WasenderAPI: Duplicate message skipped: {$messageId}");
            return;
        }

        // ── Resolve the CONTACT phone number ────────────────────────────────────
        // For inbound: the sender IS the contact (cleanedSenderPn / cleanedParticipantPn)
        // For outbound (fromMe): the contact is the RECIPIENT — use remoteJid
        if ($fromMe) {
            $remoteJid    = $key['remoteJid'] ?? '';
            $contactPhone = preg_replace('/[^0-9]/', '', explode('@', $remoteJid)[0] ?? '') ?: null;
        } else {
            $contactPhone = $key['cleanedParticipantPn']   // group sender
                ?? $key['cleanedSenderPn']                 // private sender
                ?? null;

            if (!$contactPhone) {
                // Last resort: try to extract from remoteJid if it looks like a number
                $remoteJid    = $key['remoteJid'] ?? '';
                $possible     = preg_replace('/[^0-9]/', '', explode('@', $remoteJid)[0] ?? '');
                $contactPhone = $possible ?: null;
            }
        }

        if (!$contactPhone) {
            Log::warning('WasenderAPI: Could not resolve contact phone number', ['key' => $key]);
            return;
        }

        // Normalise to E.164 with leading +
        $contactPhone = str_starts_with($contactPhone, '+') ? $contactPhone : "+{$contactPhone}";

        // ── Determine our number ─────────────────────────────────────────────
        $ourNumber = config('whatsapp.wasender.from_number', '');

        // from_number / to_number differ based on direction
        $fromNumber = $fromMe ? $ourNumber : $contactPhone;
        $toNumber   = $fromMe ? $contactPhone : $ourNumber;

        // ── Extract unified text body ──────────────────────────────────────────
        $body = trim((string) ($messages['messageBody'] ?? ''));

        // ── Detect teacher confirmation replies (inbound only) ─────────────────
        if (!$fromMe) {
            $this->maybeHandleTeacherConfirmation($contactPhone, $body);

            // ── Report submission flow ─────────────────────────────────────────
            // If this teacher has a session awaiting a report, treat the message
            // as a candidate report, echo it back, and send a confirmation poll.
            // If the method returns true the message was consumed as a report
            // candidate — we still store it in the inbox below for visibility.
            $this->maybeHandleReportSubmission($contactPhone, $body);
        }

        // ── Extract media ──────────────────────────────────────────────────────
        [$mediaUrl, $mediaMime, $msgType] = $this->extractMedia($messages, $messageId);

        // ── Resolve Guardian and Ticket ──────────────────────────────────────
        $phoneWithoutPlus = ltrim($contactPhone, '+');
        $guardian = Guardian::where('phone', $contactPhone)
            ->orWhere('phone', $phoneWithoutPlus)
            ->first();

        if (!$guardian) {
            $guardian = Guardian::create([
                'name'  => 'Unknown Contact',
                'phone' => $contactPhone,
            ]);
        }

        // Auto-update guardian name if still unknown
        if ($guardian->name === 'Unknown Contact') {
            $linked = Student::where('whatsapp_number', $contactPhone)->first()
                ?? Student::where('whatsapp_number', $phoneWithoutPlus)->first()
                ?? Teacher::where('whatsapp_number', $contactPhone)->first()
                ?? Teacher::where('whatsapp_number', $phoneWithoutPlus)->first();

            if ($linked) {
                $guardian->update(['name' => $linked->name]);
            }
        }

        $ticket = Ticket::where('guardian_id', $guardian->id)
            ->whereIn('status', [TicketStatus::Open, TicketStatus::Pending])
            ->latest()
            ->first();

        if (!$ticket) {
            $ticket = Ticket::create([
                'ticket_number' => Ticket::generateTicketNumber(),
                'guardian_id'   => $guardian->id,
                'status'        => TicketStatus::Open,
                'priority'      => TicketPriority::Normal,
                'channel'       => 'whatsapp',
                'subject'       => 'New WhatsApp Inquiry',
            ]);
        } elseif ($ticket->status === TicketStatus::Pending) {
            // Re-open pending ticket on new inbound message only
            if (!$fromMe) {
                $ticket->update(['status' => TicketStatus::Open]);
            }
        }

        // Auto-link student/teacher to ticket (inbound only to avoid overrides)
        if (!$fromMe && !$ticket->student_id && !$ticket->teacher_id) {
            $student = $guardian->students()->first()
                ?? Student::where('whatsapp_number', $contactPhone)->first();
            $teacher = Teacher::where('whatsapp_number', $contactPhone)->first();

            if ($student) {
                $ticket->update(['student_id' => $student->id]);
            } elseif ($teacher) {
                $ticket->update(['teacher_id' => $teacher->id]);
            }
        }

        // ── Auto-assign session supervisor for load balancing ────────────────
        // If the ticket has no session supervisor yet, try to find the supervisor
        // responsible for this contact's session today and assign them.
        if (!$ticket->session_supervisor_id) {
            try {
                app(SessionLoadBalancerService::class)
                    ->assignTicketToSessionSupervisor($ticket, $contactPhone);
                $ticket->refresh();
            } catch (\Throwable $e) {
                Log::warning('SessionLoadBalancer: auto-assign failed for ticket #' . $ticket->id . ': ' . $e->getMessage());
            }
        }

        // ── Resolve reply context ────────────────────────────────────────────
        $replyToMessageId = null;
        $quotedMsgId = $messages['message']['extendedTextMessage']['contextInfo']['stanzaId']
            ?? $messages['message']['imageMessage']['contextInfo']['stanzaId']
            ?? null;

        if ($quotedMsgId) {
            $parentMsg = WhatsappMessage::where('wa_message_id', $quotedMsgId)->first();
            if ($parentMsg) {
                $replyToMessageId = $parentMsg->id;
            }
        }

        // ── Store message ────────────────────────────────────────────────────
        $deliveryStatus = $fromMe
            ? DeliveryStatus::Sent       // outbound: at minimum it was sent
            : DeliveryStatus::Delivered; // inbound: we received it

        $whatsappMessage = WhatsappMessage::create([
            'wa_message_id'       => $messageId,
            'ticket_id'           => $ticket->id,
            'direction'           => $direction,
            'from_number'         => $fromNumber,
            'to_number'           => $toNumber,
            'message_type'        => $msgType,
            'content'             => $body,
            'media_url'           => $mediaUrl,
            'media_mime_type'     => $mediaMime,
            'delivery_status'     => $deliveryStatus,
            'reply_to_message_id' => $replyToMessageId,
            'timestamp'           => now(),
        ]);

        // Update ticket preview — always; unread count only for inbound messages
        $ticketUpdates = [
            'last_message_preview' => Str::limit($body ?: 'Media Message', 100),
            'last_message_at'      => now(),
        ];
        if (!$fromMe) {
            $ticketUpdates['unread_count'] = ($ticket->unread_count ?? 0) + 1;
        }
        $ticket->update($ticketUpdates);

        // ── Notifications (inbound only — no need to notify ourselves) ──────
        if (!$fromMe) {
            $senderName = $ticket->guardian?->name ?? $contactPhone;
            $preview    = Str::limit($body ?: $this->mediaPreviewText($msgType), 80);

            // Notify the assigned session supervisor (preferred) or all admins as fallback
            $supervisorId = $ticket->session_supervisor_id;

            AppNotification::notifyAdmins(
                type:  'message',
                title: "رسالة جديدة من {$senderName}",
                body:  $preview,
                data:  ['ticket_id' => $ticket->id, 'guardian_name' => $senderName],
            );

            try {
                $fcmService = \App\Services\FcmService::getInstance();

                if ($supervisorId) {
                    // Push only to the assigned supervisor
                    $fcmService->sendToUser(
                        userId: $supervisorId,
                        title:  "رسالة جديدة من {$senderName}",
                        body:   $preview,
                        data:   [
                            'type'      => 'message',
                            'ticket_id' => (string) $ticket->id,
                        ],
                    );
                } else {
                    // No supervisor yet — fall back to notifying all admins
                    $fcmService->sendToAllAdmins(
                        title: "رسالة جديدة من {$senderName}",
                        body:  $preview,
                        data:  [
                            'type'      => 'message',
                            'ticket_id' => (string) $ticket->id,
                        ],
                    );
                }
            } catch (\Throwable $e) {
                Log::warning('FCM push failed', ['error' => $e->getMessage()]);
            }
        }

        // ── Real-time WebSocket event (both directions) ───────────────────
        event(new \App\Events\TicketMessageCreated($ticket, $whatsappMessage));

        Log::info('WasenderAPI: Message stored', [
            'id'        => $whatsappMessage->id,
            'direction' => $direction->value,
            'from'      => $fromNumber,
            'type'      => $msgType->value,
        ]);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Delivery Status Update Handler
    // ──────────────────────────────────────────────────────────────────────────

    private function handleStatusUpdate(): void
    {
        // Wasender messages.update payload:
        // { "event": "messages.update", "data": { "update": { "key": { "id": "..." }, "update": { "status": 2 } } } }
        $update    = $this->payload['data']['update'] ?? [];
        $messageId = $update['key']['id'] ?? null;
        $status    = $update['update']['status'] ?? null;

        if (!$messageId || $status === null) {
            return;
        }

        // Map Wasender numeric status to our string status
        $statusString = match ((int) $status) {
            0       => 'error',
            1       => 'pending',
            2       => 'sent',
            3       => 'delivered',
            4       => 'read',
            default => 'unknown',
        };

        $message = WhatsappMessage::where('wa_message_id', $messageId)->first();

        if (!$message) {
            return;
        }

        $message->update(['delivery_status' => $statusString]);

        \App\Models\DeliveryLog::create([
            'message_id'   => $message->id,
            'status'       => $statusString,
            'bsp_response' => $this->payload,
            'attempted_at' => now(),
        ]);

        // Broadcast real-time status update (Flutter updates tick icons)
        event(new \App\Events\TicketMessageStatusUpdated($message));
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Teacher Confirmation Flow
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * If the incoming message looks like a teacher session confirmation (1/2),
     * update the class session status accordingly.
     *
     * Ported directly from ProcessTwilioInboundMessageJob — same business logic.
     */
    private function maybeHandleTeacherConfirmation(string $phone, string $body): void
    {
        $yesPhrasesInteractive = ['1', 'yes', 'yes, joined', 'yes, completed', 'نعم', 'نعم، انضم', 'نعم انضم', 'نعم، اكتملت', 'نعم اكتملت', 'yes_joined', 'yes_completed'];
        $noPhrasesInteractive  = ['2', 'no', 'no, didn\'t join', 'no, didn\'t complete', 'لا', 'لا، لم ينضم', 'لا لم ينضم', 'لا، لم تكتمل', 'لا لم تكتمل', 'no_joined', 'no_completed'];
        $ambiguousBodyOnly     = ['yes', 'no', 'نعم', 'لا'];

        $check = mb_strtolower(trim($body));

        // Reject ambiguous single-word replies to prevent accidental confirmation
        if (in_array($check, $ambiguousBodyOnly, true)) {
            return;
        }

        $normalizedReply = null;

        if (in_array($check, ['1', '٢'], true) || in_array($check, $yesPhrasesInteractive, true)) {
            $normalizedReply = '1';
        } elseif (in_array($check, ['2', '٢'], true) || in_array($check, $noPhrasesInteractive, true)) {
            $normalizedReply = '2';
        }

        if ($normalizedReply === null) {
            return;
        }

        $handled = $this->handleTeacherConfirmation($phone, $normalizedReply);

        if ($handled) {
            Log::info('WasenderAPI: Teacher confirmation applied', [
                'phone'   => $phone,
                'matched' => $check,
                'reply'   => $normalizedReply,
            ]);
        }
    }

    /**
     * Apply session status update based on teacher's confirmation reply.
     */
    private function handleTeacherConfirmation(string $phone, string $reply): bool
    {
        $reminder = Reminder::where('recipient_phone', $phone)
            ->where('recipient_type', 'teacher')
            ->where('confirmation_status', 'awaiting')
            ->where('status', 'sent')
            ->latest('sent_at')
            ->first();

        if (!$reminder || !$reminder->class_session_id) {
            return false;
        }

        $maxAgeHours = (int) config('whatsapp.teacher_confirmation_max_age_hours', 72);
        if ($reminder->sent_at && $reminder->sent_at->lt(now()->subHours($maxAgeHours))) {
            Log::warning('WasenderAPI: Teacher confirmation ignored — stale reminder', [
                'reminder_id'      => $reminder->id,
                'class_session_id' => $reminder->class_session_id,
            ]);
            return false;
        }

        $session = ClassSession::find($reminder->class_session_id);
        if (!$session || in_array($session->status, ['completed', 'cancelled'], true)) {
            return false;
        }

        $phase = $reminder->reminder_phase;

        if ($reply === '1') {
            $reminder->update(['confirmation_status' => 'confirmed']);

            if (in_array($phase, ['post_end', 'post_end_2'])) {
                $session->update(['status' => 'completed', 'attendance_status' => 'both_joined']);
            } else {
                $session->update(['status' => 'running', 'attendance_status' => 'both_joined']);
            }

            // Cancel pending pre-class reminders for this session
            Reminder::where('class_session_id', $session->id)
                ->where('status', 'pending')
                ->whereIn('reminder_phase', ['before', 'at_start', 'after'])
                ->update([
                    'status'         => 'cancelled',
                    'failure_reason' => 'Teacher confirmed — session active',
                ]);

            // Mark other awaiting reminders for same session as no_reply
            Reminder::where('class_session_id', $session->id)
                ->where('confirmation_status', 'awaiting')
                ->where('id', '!=', $reminder->id)
                ->update(['confirmation_status' => 'no_reply']);
        } else {
            $reminder->update(['confirmation_status' => 'denied']);

            if (in_array($phase, ['post_end', 'post_end_2'])) {
                $session->update(['status' => 'running']);
            } else {
                $session->update(['status' => 'pending', 'attendance_status' => 'no_show']);
            }
        }

        return true;
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Media Helpers
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Extract media information from the Wasender message payload.
     *
     * Wasender delivers media as encrypted files. We can either:
     *   (a) Call Wasender's /api/decrypt-media endpoint, OR
     *   (b) Manually decrypt using HKDF + AES-256-CBC (matching WhatsApp protocol)
     *
     * We use strategy (a) — the Wasender decrypt API — for simplicity.
     *
     * @return array{0: ?string, 1: ?string, 2: MessageType}
     */
    private function extractMedia(array $messages, string $messageId): array
    {
        $rawMessage = $messages['message'] ?? [];
        $mediaTypes = [
            'imageMessage'    => ['image', MessageType::Image],
            'videoMessage'    => ['video', MessageType::Video],
            'audioMessage'    => ['audio', MessageType::Audio],
            'documentMessage' => ['document', MessageType::Document],
            'stickerMessage'  => ['sticker', MessageType::Image],
        ];

        foreach ($mediaTypes as $key => [$mediaType, $msgType]) {
            if (!isset($rawMessage[$key])) {
                continue;
            }

            $mediaObj = $rawMessage[$key];
            $encUrl   = $mediaObj['url']      ?? null;
            $mediaKey = $mediaObj['mediaKey'] ?? null;
            $mime     = $mediaObj['mimetype'] ?? null;

            if (!$encUrl || !$mediaKey) {
                // No keys to decrypt — store raw URL as fallback
                return [$encUrl, $mime, $msgType];
            }

            // Pass the FULL messages payload — Wasender decrypt-media requires it
            $publicUrl = $this->decryptMediaViaApi($messages);

            if ($publicUrl) {
                // Download and store permanently on our server
                $storedUrl = $this->downloadAndStore($publicUrl, $mime ?? 'application/octet-stream', $messageId);
                return [$storedUrl ?? $publicUrl, $mime, $msgType];
            }

            return [$encUrl, $mime, $msgType];
        }

        return [null, null, MessageType::Text];
    }

    /**
     * Call Wasender's /api/decrypt-media endpoint to get a temporary public URL.
     *
     * The API requires the FULL original webhook messages object:
     *   POST /api/decrypt-media
     *   Body: { "data": { "messages": { ...full messages payload... } } }
     *
     * Logs full request/response to webhook_debug.log for diagnostics.
     */
    private function decryptMediaViaApi(array $messagesPayload): ?string
    {
        $apiKey  = config('whatsapp.wasender.api_key');
        $baseUrl = config('whatsapp.wasender.base_url', 'https://www.wasenderapi.com/api');

        $requestBody = ['data' => ['messages' => $messagesPayload]];

        $debugLog = storage_path('logs/webhook_debug.log');
        file_put_contents($debugLog, '[' . date('Y-m-d H:i:s') . "] DECRYPT-REQ | " . substr(json_encode($messagesPayload), 0, 120) . "\n", FILE_APPEND);

        try {
            $response = Http::withToken($apiKey)
                ->asJson()
                ->timeout(20)
                ->post("{$baseUrl}/decrypt-media", $requestBody);

            $body = substr($response->body(), 0, 500);
            file_put_contents($debugLog, '[' . date('Y-m-d H:i:s') . "] DECRYPT-RES | status={$response->status()} body={$body}\n", FILE_APPEND);

            if ($response->successful()) {
                // Try multiple possible JSON paths Wasender may return
                $publicUrl = $response->json('data.publicUrl')
                    ?? $response->json('publicUrl')
                    ?? $response->json('data.url')
                    ?? $response->json('url')
                    ?? null;

                file_put_contents($debugLog, '[' . date('Y-m-d H:i:s') . "] DECRYPT-URL | " . ($publicUrl ?? 'NULL') . "\n", FILE_APPEND);
                return $publicUrl;
            }

            Log::warning('WasenderAPI: decrypt-media failed', [
                'status' => $response->status(),
                'body'   => $response->body(),
            ]);
        } catch (\Throwable $e) {
            file_put_contents($debugLog, '[' . date('Y-m-d H:i:s') . "] DECRYPT-EX | " . $e->getMessage() . "\n", FILE_APPEND);
            Log::warning('WasenderAPI: decrypt-media exception', ['error' => $e->getMessage()]);
        }

        return null;
    }

    /**
     * Download a file from the given URL and store it in public storage.
     * Returns the publicly accessible URL, or null on failure.
     */
    private function downloadAndStore(string $url, string $mime, string $messageId): ?string
    {
        try {
            $response = Http::timeout(30)->get($url);

            if (!$response->successful()) {
                return null;
            }

            $extension = $this->extensionFromMime($mime);
            $filename  = Str::ulid() . '.' . $extension;
            $path      = 'tickets/inbound/' . $filename;

            Storage::disk('public')->put($path, $response->body());

            return url(Storage::url($path));
        } catch (\Throwable $e) {
            Log::warning('WasenderAPI: Failed to download/store media', [
                'url'   => $url,
                'error' => $e->getMessage(),
            ]);
            return null;
        }
    }

    private function extensionFromMime(string $mime): string
    {
        return match (true) {
            str_contains($mime, 'jpeg')  => 'jpeg',
            str_contains($mime, 'png')   => 'png',
            str_contains($mime, 'webp')  => 'webp',
            str_contains($mime, 'gif')   => 'gif',
            str_contains($mime, 'mp4')   => 'mp4',
            str_contains($mime, 'ogg')   => 'ogg',
            str_contains($mime, 'mpeg')  => 'mp3',
            str_contains($mime, 'audio') => 'm4a',
            str_contains($mime, 'pdf')   => 'pdf',
            default                      => 'bin',
        };
    }

    private function mediaPreviewText(MessageType $type): string
    {
        return match ($type) {
            MessageType::Image    => '📷 صورة',
            MessageType::Video    => '🎥 فيديو',
            MessageType::Audio    => '🎵 صوت',
            MessageType::Document => '📄 مستند',
            default               => '📎 ملف',
        };
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Failure Handler
    // ──────────────────────────────────────────────────────────────────────────

    public function failed(\Throwable $e): void
    {
        Log::error('ProcessWasenderInboundMessageJob permanently failed', [
            'error'   => $e->getMessage(),
            'payload' => $this->payload,
        ]);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // SESSION REPORT FLOW
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * Step 1 — Called right after the teacher's post_end poll vote = YES.
     *
     * Sets report_status = 'awaiting' and sends the teacher a plain-text
     * prompt asking for a session report.
     */
    private function maybeRequestSessionReport(\App\Models\ClassSession $session, ?string $teacherPhone): void
    {
        if (!$teacherPhone) {
            Log::warning('ReportFlow: cannot request report — teacher phone unknown', ['session_id' => $session->id]);
            return;
        }

        try {
            $session->update(['report_status' => 'awaiting', 'report_nudge_count' => 0]);

            $studentName = $session->student?->name ?? 'الطالب';
            $subject     = $session->title ?? 'الحصة';
            $timeRaw     = $session->rescheduled_start_time ?? $session->start_time;
            $timeTag     = $timeRaw ? ' (' . substr((string) $timeRaw, 0, 5) . ')' : '';

            $message = implode("\n", [
                "📝 *تقرير الحصة*",
                "الطالب: {$studentName}",
                "",
                "يرجى إرسال تقرير الحصة",
                "وسنقوم بإرساله للطالب بعد تأكيدك.",
            ]);

            /** @var \App\Services\WhatsApp\WasenderWhatsAppService $whatsApp */
            $whatsApp = app(\App\Services\WhatsApp\WhatsAppServiceInterface::class);
            $whatsApp->sendText($teacherPhone, $message);

            Log::info('ReportFlow: report requested from teacher', [
                'session_id'    => $session->id,
                'teacher_phone' => $teacherPhone,
            ]);
        } catch (\Throwable $e) {
            Log::warning('ReportFlow: failed to request report', [
                'session_id' => $session->id,
                'error'      => $e->getMessage(),
            ]);
        }
    }

    /**
     * Step 2 — Called from handleInboundMessage() for every inbound teacher message.
     *
     * If the sending teacher has a session in 'awaiting' report_status, the
     * message body is treated as a candidate report:
     *   - Stored temporarily in session.teacher_report
     *   - Echoed back to the teacher with a confirmation poll:
     *       "هل هذا هو تقرير الحصة؟"
     *       ✅ نعم، أرسل للطالب
     *       ❌ لا، تجاهل
     *   - session.report_status set to 'confirming'
     *
     * Empty bodies (e.g. voice notes whose text is blank) are ignored.
     */
    private function maybeHandleReportSubmission(string $phone, string $body): void
    {
        if (trim($body) === '') {
            return;
        }

        // Find the teacher by WhatsApp number
        $phoneWithoutPlus = ltrim($phone, '+');
        $teacher = \App\Models\Teacher::where('whatsapp_number', $phone)
            ->orWhere('whatsapp_number', $phoneWithoutPlus)
            ->first();

        if (!$teacher) {
            return; // Not a teacher — nothing to do
        }

        // Find the most recently completed session for this teacher that is awaiting a report
        $session = \App\Models\ClassSession::where('teacher_id', $teacher->id)
            ->where('report_status', 'awaiting')
            ->where('status', 'completed')
            ->orderByDesc('session_date')
            ->orderByDesc('updated_at')
            ->first();

        if (!$session) {
            return; // No session waiting for a report
        }

        try {
            // Store the candidate report text and move to 'confirming'
            $session->update([
                'teacher_report' => $body,
                'report_status'  => 'confirming',
            ]);

            $studentName = $session->student?->name ?? 'الطالب';
            $subject     = $session->title ?? 'الحصة';

            // Build the echo message so the teacher can review what they sent
            $echoText = implode("\n", [
                "📋 *مراجعة التقرير*",
                "الحصة: {$subject} — {$studentName}",
                "",
                $body,
            ]);

            /** @var \App\Services\WhatsApp\WasenderWhatsAppService $whatsApp */
            $whatsApp = app(\App\Services\WhatsApp\WhatsAppServiceInterface::class);

            // Echo the report back so the teacher sees exactly what will be sent
            $whatsApp->sendText($phone, $echoText);

            // Confirmation poll — question is prefixed with a unique marker so
            // handlePollVote() can identify it as a report-confirm poll.
            $pollQuestion = 'تأكيد_تقرير:' . $session->id;
            $whatsApp->sendPoll(
                to: $phone,
                name: $pollQuestion,
                options: ['نعم، أرسل التقرير للطالب', 'لا، تجاهل هذه الرسالة'],
                selectableCount: 1,
            );

            Log::info('ReportFlow: candidate report received — awaiting teacher confirmation', [
                'session_id' => $session->id,
                'teacher'    => $phone,
                'body_len'   => mb_strlen($body),
            ]);
        } catch (\Throwable $e) {
            Log::warning('ReportFlow: failed to send report confirmation poll', [
                'session_id' => $session->id,
                'error'      => $e->getMessage(),
            ]);
        }
    }

    /**
     * Step 3 — Called from handlePollVote() when the poll question starts with 'تأكيد_تقرير:'.
     *
     * Parses the session ID from the question, then:
     *   YES → saves the report, forwards it to the student, closes the flow.
     *   NO  → resets report to null, status back to 'awaiting', invites retry.
     */
    private function handleReportConfirmPoll(
        string $pollQuestion,
        ?string $voteValue,
        ?string $voterPhone
    ): void {
        // Extract session ID from the encoded poll question (format: 'تأكيد_تقرير:<id>')
        $sessionId = (int) trim(mb_substr($pollQuestion, mb_strpos($pollQuestion, ':') + 1));
        if ($sessionId <= 0) {
            Log::warning('ReportFlow: could not parse session_id from poll question', ['q' => $pollQuestion]);
            return;
        }

        $session = \App\Models\ClassSession::find($sessionId);
        if (!$session || $session->report_status !== 'confirming') {
            Log::info('ReportFlow: session not in confirming state — ignoring vote', ['session_id' => $sessionId]);
            return;
        }

        /** @var \App\Services\WhatsApp\WasenderWhatsAppService $whatsApp */
        $whatsApp = app(\App\Services\WhatsApp\WhatsAppServiceInterface::class);

        if ($voteValue === 'yes') {
            // ── Teacher approved → forward the report to the student ───────────
            $reportBody  = $session->teacher_report ?? '';
            $studentName = $session->student?->name ?? 'الطالب';
            $subject     = $session->title ?? 'الحصة';
            $teacherName = $session->teacher?->name ?? 'المعلم';
            $timeRaw     = $session->rescheduled_start_time ?? $session->start_time;
            $timeTag     = $timeRaw ? ' (' . substr((string) $timeRaw, 0, 5) . ')' : '';

            $studentMessage = implode("\n", [
                "📋 *تقرير الحصة*",
                "من المعلم: {$teacherName}",
                "",
                $reportBody,
            ]);

            $studentPhone = $session->student?->whatsapp_number;

            if ($studentPhone) {
                try {
                    $whatsApp->sendText($studentPhone, $studentMessage);
                    Log::info('ReportFlow: report forwarded to student', [
                        'session_id'    => $session->id,
                        'student_phone' => $studentPhone,
                    ]);
                } catch (\Throwable $e) {
                    Log::warning('ReportFlow: failed to send report to student', [
                        'session_id' => $session->id,
                        'error'      => $e->getMessage(),
                    ]);
                }
            } else {
                Log::warning('ReportFlow: student has no WhatsApp number — report not forwarded', [
                    'session_id' => $session->id,
                    'student_id' => $session->student_id,
                ]);
            }

            // Mark report as confirmed regardless of whether the student has a number
            $session->update(['report_status' => 'confirmed']);

            // Acknowledge to teacher
            try {
                $ack = $studentPhone
                    ? "✅ تم إرسال التقرير لـ {$studentName} بنجاح."
                    : "✅ تم حفظ التقرير. ملاحظة: لا يوجد رقم واتساب مسجّل للطالب.";
                $whatsApp->sendText($voterPhone ?? '', $ack);
            } catch (\Throwable) {}

        } else {
            // ── Teacher rejected → reset and invite a retry ───────────────────
            $session->update([
                'teacher_report' => null,
                'report_status'  => 'awaiting',
            ]);

            Log::info('ReportFlow: teacher discarded candidate report — reset to awaiting', [
                'session_id' => $session->id,
            ]);

            try {
                $whatsApp->sendText(
                    $voterPhone ?? '',
                    "حسناً، تم تجاهل الرسالة.\nيرجى إرسال التقرير الصحيح وسنطلب تأكيدك مجدداً."
                );
            } catch (\Throwable) {}
        }
    }
}
