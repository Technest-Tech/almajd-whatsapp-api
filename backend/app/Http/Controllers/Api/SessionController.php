<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Enums\DeliveryStatus;
use App\Enums\MessageDirection;
use App\Enums\MessageType;
use App\Enums\TicketPriority;
use App\Enums\TicketStatus;
use App\Http\Controllers\Controller;
use App\Models\ClassSession;
use App\Models\Guardian;
use App\Models\Reminder;
use App\Models\Ticket;
use App\Models\WhatsappMessage;
use App\Models\WhatsappTemplate;
use App\Services\ApiResponseService;
use App\Services\SessionService;
use App\Services\WhatsApp\WhatsAppServiceInterface;
use App\Support\ReminderTemplateResolver;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class SessionController extends Controller
{
    public function __construct(
        private readonly SessionService $sessionService,
        private readonly ApiResponseService $response,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $paginator = $this->sessionService->list(
            filters: $request->only(['date', 'from', 'to', 'status', 'teacher_id', 'supervisor_id']),
            perPage: (int) $request->input('per_page', 20),
        );
        return $this->response->paginated($paginator);
    }

    public function show(int $id): JsonResponse
    {
        return $this->response->success($this->sessionService->show($id));
    }

    public function pendingCount(Request $request): JsonResponse
    {
        $count = \App\Models\ClassSession::where('status', 'pending')->count();
        return $this->response->success(['count' => $count]);
    }

    public function updateStatus(Request $request, int $id): JsonResponse
    {
        $data = $request->validate([
            'status' => 'required|in:scheduled,completed,cancelled,running,pending,rescheduled',
            'attendance_status' => 'nullable|in:pending,teacher_joined,student_absent,both_joined,no_show',
            'cancellation_reason' => 'nullable|string|max:500',
            'rescheduled_date' => 'nullable|date',
            'rescheduled_start_time' => 'nullable|string|max:10',
            'rescheduled_end_time' => 'nullable|string|max:10',
        ]);

        $session = ClassSession::findOrFail($id);

        $updateData = ['status' => $data['status']];

        if ($data['status'] === 'cancelled' && !empty($data['cancellation_reason'])) {
            $updateData['cancellation_reason'] = $data['cancellation_reason'];
        }

        if ($data['status'] === 'rescheduled') {
            if (!empty($data['rescheduled_date'])) {
                $updateData['rescheduled_date'] = $data['rescheduled_date'];
            }
            if (!empty($data['rescheduled_start_time'])) {
                $updateData['rescheduled_start_time'] = $data['rescheduled_start_time'];
            }
            if (!empty($data['rescheduled_end_time'])) {
                $updateData['rescheduled_end_time'] = $data['rescheduled_end_time'];
            }
        }

        if (isset($data['attendance_status'])) {
            $updateData['attendance_status'] = $data['attendance_status'];
        }

        $session->update($updateData);

        return $this->response->success($session->refresh(), 'Session updated');
    }

    /**
     * Send an instant manual reminder for a session.
     */
    public function sendReminder(Request $request, int $id): JsonResponse
    {
        $data = $request->validate([
            'recipient_type' => 'required|in:student,teacher',
        ]);

        $session = ClassSession::with(['student.guardian', 'teacher'])->findOrFail($id);

        $recipientType = $data['recipient_type'];
        $phone = null;
        $name = null;
        $message = '';

        $teacher = $session->teacher;
        $teacherName = $teacher?->name ?? 'غير محدد';
        $studentName = $session->student?->name ?? 'غير محدد';

        if ($recipientType === 'student') {
            $student = $session->student;
            $phone = $student?->guardian?->phone ?? $student?->phone;
            $name = $student?->name;
            $logicalTemplateKey = 'student_before_reminder';
            $templateParams = [
                '1' => $session->title,
                '2' => $session->start_time,
                '3' => $teacherName,
                '4' => $teacher?->zoom_link ?? '',
            ];
            $message = "📚 تذكير: لديك حصة *{$session->title}*\n⏰ الوقت: {$session->start_time}\n👨‍🏫 المعلم: {$teacherName}\nيرجى الحضور";
        } else {
            $phone = $teacher?->whatsapp_number;
            $name = $teacher?->name;
            $logicalTemplateKey = 'teacher_before_alert';
            $templateParams = [];
            $message = "📚 تذكير: لديك حصة *{$session->title}*\n⏰ الوقت: {$session->start_time}\n👤 الطالب: {$studentName}\nيرجى الحضور";
        }

        if (!$phone) {
            return $this->response->error('رقم الهاتف غير متوفر', 422);
        }

        $approved = WhatsappTemplate::where('status', 'approved')->get();
        $waTemplate = ReminderTemplateResolver::resolve($logicalTemplateKey, $approved);
        $templateSid = $waTemplate?->content_sid;
        $message = ReminderTemplateResolver::resolveBody($waTemplate, $templateParams, $message);

        // Create reminder record
        $reminder = Reminder::create([
            'type'             => 'session_reminder',
            'recipient_type'   => $recipientType,
            'reminder_phase'   => 'at_start',
            'class_session_id' => $session->id,
            'recipient_phone'  => $phone,
            'recipient_name'   => $name,
            'template_name'    => $logicalTemplateKey,
            'template_sid'     => $templateSid,
            'template_params'  => $templateParams,
            'message_body'     => $message,
            'scheduled_at'     => now(),
            'status'           => 'pending',
        ]);

        try {
            $whatsAppService = app(WhatsAppServiceInterface::class);
            if (!empty($templateSid)) {
                $whatsAppService->sendTemplate(
                    to: $phone,
                    templateName: $templateSid,
                    params: $templateParams,
                    language: 'ar',
                );
            } else {
                $whatsAppService->sendText(to: $phone, message: $message);
            }
            $reminder->update(['status' => 'sent', 'sent_at' => now()]);
        } catch (\Throwable $e) {
            Log::error('Reminder send failed: ' . $e->getMessage());
            $reminder->update(['status' => 'failed', 'failure_reason' => $e->getMessage()]);
        }

        $inboxResult = $this->createInboxMessage($phone, $name, $message);

        return $this->response->success([
            'reminder' => $reminder->refresh(),
            'inbox'    => $inboxResult,
        ], 'تم إرسال التذكير');
    }

    /**
     * Create a WhatsappMessage in the inbox so supervisors see the sent reminder.
     */
    private function createInboxMessage(string $phone, ?string $name, string $message): array
    {
        $phoneWithPlus = str_starts_with($phone, '+') ? $phone : '+' . $phone;

        // Find or create guardian
        $guardian = Guardian::where('phone', $phone)
            ->orWhere('phone', $phoneWithPlus)
            ->first();

        if (!$guardian) {
            $guardian = Guardian::create([
                'name'  => $name ?? 'Unknown',
                'phone' => $phoneWithPlus,
            ]);
        }

        // Find or create ticket
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
                'subject'       => 'تذكير بالحصة',
            ]);
        }

        // Create outbound message
        $twilioNumber = config('whatsapp.twilio.from_number', env('TWILIO_FROM_NUMBER', '+14155238886'));

        $whatsappMsg = WhatsappMessage::create([
            'wa_message_id'   => 'RMD_' . Str::ulid(),
            'ticket_id'       => $ticket->id,
            'direction'       => MessageDirection::Outbound,
            'from_number'     => $twilioNumber,
            'to_number'       => $phoneWithPlus,
            'message_type'    => MessageType::Text,
            'content'         => $message,
            'delivery_status' => DeliveryStatus::Sent,
            'timestamp'       => now(),
        ]);

        // Update ticket preview + increment unread
        $ticket->update([
            'last_message_preview' => Str::limit($message, 80),
            'last_message_at'      => now(),
            'unread_count'         => ($ticket->unread_count ?? 0) + 1,
        ]);

        // Fire WebSocket event
        event(new \App\Events\TicketMessageCreated($ticket, $whatsappMsg));

        return [
            'ticket_id'  => $ticket->id,
            'message_id' => $whatsappMsg->id,
        ];
    }
}
