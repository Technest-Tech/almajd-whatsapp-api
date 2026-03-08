<?php

declare(strict_types=1);

namespace App\Services;

use App\Enums\TemplateStatus;
use App\Models\WhatsappTemplate;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

/**
 * Manages WhatsApp Message Templates via Twilio Content API.
 *
 * Twilio Content API docs:
 * https://www.twilio.com/docs/content/whatsapp-api
 */
class TemplateService
{
    private string $accountSid;
    private string $authToken;
    private string $fromNumber;

    public function __construct()
    {
        $this->accountSid = config('whatsapp.twilio.account_sid');
        $this->authToken  = config('whatsapp.twilio.auth_token');
        $this->fromNumber = config('whatsapp.twilio.from_number');
    }

    // ── List ──────────────────────────────────────────────────────────────────

    public function list(array $filters = [], int $perPage = 20): LengthAwarePaginator
    {
        $query = WhatsappTemplate::latest();

        if (!empty($filters['status'])) {
            $query->where('status', $filters['status']);
        }
        if (!empty($filters['search'])) {
            $query->where('name', 'like', '%' . $filters['search'] . '%');
        }

        return $query->paginate($perPage);
    }

    public function listApproved(): \Illuminate\Database\Eloquent\Collection
    {
        return WhatsappTemplate::approved()->orderBy('name')->get();
    }

    // ── Create (save locally + create on Twilio) ──────────────────────────────

    public function create(array $data): WhatsappTemplate
    {
        // Save to DB first as draft
        $template = WhatsappTemplate::create([
            'name'             => $data['name'],
            'language'         => $data['language'] ?? 'ar',
            'category'         => $data['category'] ?? 'UTILITY',
            'body_template'    => $data['body_template'],
            'header_type'      => $data['header_type'] ?? 'none',
            'header_text'      => $data['header_text'] ?? null,
            'footer_text'      => $data['footer_text'] ?? null,
            'variables_schema' => $data['variables_schema'] ?? [],
            'status'           => TemplateStatus::Draft,
        ]);

        // Create on Twilio Content API
        try {
            $contentSid = $this->createOnTwilio($template);
            $template->update([
                'content_sid' => $contentSid,
                'status'      => TemplateStatus::Draft,
            ]);
        } catch (\Throwable $e) {
            Log::error('Twilio Content API create failed', [
                'template_id' => $template->id,
                'error'       => $e->getMessage(),
            ]);
            // Template saved locally — admin can retry submit later
        }

        return $template->refresh();
    }

    // ── Submit for Meta Approval ──────────────────────────────────────────────

    public function submitForApproval(WhatsappTemplate $template): WhatsappTemplate
    {
        if (!$template->content_sid) {
            // Try creating on Twilio first
            $contentSid = $this->createOnTwilio($template);
            $template->update(['content_sid' => $contentSid]);
        }

        // Submit WhatsApp approval request via Twilio
        $response = Http::withBasicAuth($this->accountSid, $this->authToken)
            ->post("https://content.twilio.com/v1/Content/{$template->content_sid}/ApprovalRequests/whatsapp", [
                'name'     => $template->name,
                'category' => $template->category ?? 'UTILITY',
            ]);

        if ($response->successful()) {
            $template->update([
                'status'    => TemplateStatus::Pending,
                'synced_at' => now(),
            ]);
            Log::info('Template submitted for WhatsApp approval', ['sid' => $template->content_sid]);
        } else {
            Log::error('Twilio approval submit failed', [
                'status' => $response->status(),
                'body'   => $response->body(),
            ]);
            throw new \RuntimeException('Approval submission failed: ' . $response->body());
        }

        return $template->refresh();
    }

    // ── Sync statuses from Twilio ─────────────────────────────────────────────

    public function syncFromTwilio(): int
    {
        $response = Http::withBasicAuth($this->accountSid, $this->authToken)
            ->get('https://content.twilio.com/v1/Content', [
                'PageSize' => 100,
            ]);

        if (!$response->successful()) {
            throw new \RuntimeException('Twilio sync failed: ' . $response->body());
        }

        $contents = $response->json('contents', []);
        $updated  = 0;

        foreach ($contents as $item) {
            $sid = $item['sid'] ?? null;
            if (!$sid) continue;

            $template = WhatsappTemplate::where('content_sid', $sid)->first();
            if (!$template) continue;

            // Fetch specific approval request status for this template
            $approvalResponse = Http::withBasicAuth($this->accountSid, $this->authToken)
                ->get("https://content.twilio.com/v1/Content/{$sid}/ApprovalRequests");
                
            if (!$approvalResponse->successful()) continue;
            
            $approvalInfo = $approvalResponse->json('whatsapp', []);
            $statusString = $approvalInfo['status'] ?? '';
            
            // If empty, it means it hasn't been submitted or Twilio hasn't processed it
            if (empty($statusString)) continue;

            $twilioStatus = match (strtolower($statusString)) {
                'approved' => TemplateStatus::Approved,
                'rejected' => TemplateStatus::Rejected,
                default    => TemplateStatus::Pending,
            };

            $template->update([
                'status'           => $twilioStatus,
                'rejection_reason' => $approvalInfo['rejection_reason'] ?? null,
                'synced_at'        => now(),
            ]);
            $updated++;
        }

        return $updated;
    }

    // ── Delete ────────────────────────────────────────────────────────────────

    public function delete(WhatsappTemplate $template): void
    {
        if ($template->content_sid) {
            Http::withBasicAuth($this->accountSid, $this->authToken)
                ->delete("https://content.twilio.com/v1/Content/{$template->content_sid}");
        }

        $template->delete();
    }

    // ── Internal: create on Twilio Content API ────────────────────────────────

    private function createOnTwilio(WhatsappTemplate $template): string
    {
        $body = [
            'friendly_name' => $template->name,
            'language'      => $template->language ?? 'ar',
            'types'         => [
                'twilio/text' => [
                    'body' => $template->body_template,
                ],
            ],
        ];

        $response = Http::withBasicAuth($this->accountSid, $this->authToken)
            ->asJson()
            ->post('https://content.twilio.com/v1/Content', $body);

        if (!$response->successful()) {
            throw new \RuntimeException(
                'Twilio Content API error: ' . $response->body()
            );
        }

        return $response->json('sid');
    }
}
