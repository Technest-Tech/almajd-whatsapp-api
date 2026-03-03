<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\ApiResponseService;
use App\Services\ReminderService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ReminderController extends Controller
{
    public function __construct(
        private readonly ReminderService $reminderService,
        private readonly ApiResponseService $response,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $paginator = $this->reminderService->list(
            filters: $request->only(['status', 'type', 'from', 'to']),
            perPage: (int) $request->input('per_page', 20),
        );
        return $this->response->paginated($paginator);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'type'             => 'required|in:session_reminder,guardian_notification,custom',
            'class_session_id' => 'nullable|exists:class_sessions,id',
            'recipient_phone'  => 'required|string|max:20',
            'recipient_name'   => 'nullable|string|max:255',
            'template_name'    => 'nullable|string|max:255',
            'message_body'     => 'required_without:template_name|nullable|string|max:4096',
            'scheduled_at'     => 'required|date|after:now',
        ]);

        $reminder = $this->reminderService->create($data);

        return $this->response->success($reminder, 'Reminder scheduled', code: 201);
    }

    public function cancel(int $id): JsonResponse
    {
        $reminder = $this->reminderService->cancel($id);
        return $this->response->success($reminder, 'Reminder cancelled');
    }

    public function bulkCreate(Request $request): JsonResponse
    {
        $data = $request->validate([
            'session_id'    => 'required|exists:class_sessions,id',
            'template_name' => 'required|string|max:255',
            'scheduled_at'  => 'required|date|after:now',
            'recipients'    => 'required|array|min:1',
            'recipients.*.phone' => 'required|string|max:20',
            'recipients.*.name'  => 'nullable|string|max:255',
        ]);

        $count = $this->reminderService->createSessionReminders(
            sessionId: (int) $data['session_id'],
            templateName: $data['template_name'],
            scheduledAt: \Carbon\Carbon::parse($data['scheduled_at']),
            recipients: $data['recipients'],
        );

        return $this->response->success(['count' => $count], "{$count} reminders scheduled", code: 201);
    }
}
