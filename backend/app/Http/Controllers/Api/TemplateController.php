<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\WhatsappTemplate;
use App\Services\ApiResponseService;
use App\Services\TemplateService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TemplateController extends Controller
{
    public function __construct(
        private readonly TemplateService $templateService,
        private readonly ApiResponseService $response,
    ) {}

    /**
     * GET /api/templates
     * List all templates with optional filters.
     */
    public function index(Request $request): JsonResponse
    {
        $paginator = $this->templateService->list(
            filters: $request->only(['status', 'search']),
            perPage: (int) $request->input('per_page', 20),
        );
        return $this->response->paginated($paginator);
    }

    /**
     * GET /api/templates/approved
     * Return only approved templates (for the "send template" picker in chat).
     */
    public function approved(): JsonResponse
    {
        $templates = $this->templateService->listApproved();
        return $this->response->success($templates);
    }

    /**
     * POST /api/templates
     * Create a new template locally + push to Twilio Content API.
     */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name'             => 'required|string|max:64|regex:/^[a-z0-9_]+$/|unique:whatsapp_templates,name',
            'language'         => 'nullable|string|max:10',
            'category'         => 'nullable|in:UTILITY,MARKETING,AUTHENTICATION',
            'body_template'    => 'required|string|max:1024',
            'header_type'      => 'nullable|in:none,text',
            'header_text'      => 'nullable|string|max:60',
            'footer_text'      => 'nullable|string|max:60',
            'variables_schema' => 'nullable|array',
            'variables_schema.*' => 'string|max:64',
        ]);

        $template = $this->templateService->create($data);
        return $this->response->success($template, 'Template created', code: 201);
    }

    /**
     * POST /api/templates/{id}/submit
     * Submit template to Meta via Twilio for WhatsApp approval.
     */
    public function submit(int $id): JsonResponse
    {
        $template = WhatsappTemplate::findOrFail($id);
        $template = $this->templateService->submitForApproval($template);
        return $this->response->success($template, 'Template submitted for approval');
    }

    /**
     * POST /api/templates/sync
     * Sync approval statuses from Twilio for all local templates.
     */
    public function sync(): JsonResponse
    {
        $count = $this->templateService->syncFromTwilio();
        return $this->response->success(['updated' => $count], "{$count} templates synced");
    }

    /**
     * DELETE /api/templates/{id}
     * Delete template locally and from Twilio.
     */
    public function destroy(int $id): JsonResponse
    {
        $template = WhatsappTemplate::findOrFail($id);
        $this->templateService->delete($template);
        return $this->response->success(null, 'Template deleted');
    }
}
