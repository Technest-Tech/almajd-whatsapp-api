<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Student;
use App\Models\Teacher;
use App\Models\WhatsappGroup;
use App\Services\ApiResponseService;
use App\Services\WhatsApp\WasenderSession;
use App\Services\WhatsApp\WasenderWhatsAppService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Admin "Link Groups" management.
 *
 * Lets an admin map each shared teacher↔student WhatsApp group to its
 * teacher + student so that reminders are routed to the group. See
 * App\Models\WhatsappGroup and the whatsapp_groups migration.
 */
class WhatsappGroupController extends Controller
{
    public function __construct(
        private readonly ApiResponseService $response,
    ) {}

    /**
     * List the saved teacher↔student → group mappings.
     */
    public function index(): JsonResponse
    {
        $groups = WhatsappGroup::with(['teacher:id,name,whatsapp_number', 'student:id,name'])
            ->orderByDesc('id')
            ->get();

        return $this->response->success([
            'active_number' => WasenderSession::fromNumber(),
            'groups'        => $groups,
        ], 'WhatsApp groups retrieved');
    }

    /**
     * Discover every group the active Wasender session belongs to, and
     * auto-suggest the matching teacher + student by comparing the group's
     * participant phone numbers against known teacher/student/guardian phones.
     */
    public function discover(WasenderWhatsAppService $whatsApp): JsonResponse
    {
        // getGroups() uses the active session's key, so this returns only the
        // groups the currently-active number is a member of.
        $activeNumber = WasenderSession::fromNumber();
        $groups = $whatsApp->getGroups();

        // JIDs already mapped FOR THE ACTIVE NUMBER (so the UI marks them linked).
        $mapped = WhatsappGroup::where('whatsapp_number', $activeNumber)
            ->pluck('group_jid')
            ->all();

        $suggestions = array_map(function (array $g) use ($mapped) {
            $digits = array_map([$this, 'normalizePhone'], $g['participants']);

            $teacher = Teacher::query()
                ->where(fn ($q) => $this->matchByDigits($q, 'whatsapp_number', $digits))
                ->first(['id', 'name', 'whatsapp_number']);

            // A student's contact number is stored on whatsapp_number (the same
            // value as the linked guardian's phone), so this also covers the
            // guardian being the group participant.
            $student = Student::query()
                ->where(fn ($q) => $this->matchByDigits($q, 'whatsapp_number', $digits))
                ->first(['id', 'name', 'whatsapp_number']);

            return [
                'group_jid'         => $g['jid'],
                'group_name'        => $g['name'],
                'participants'      => $g['participants'],
                'already_linked'    => in_array($g['jid'], $mapped, true),
                'suggested_teacher' => $teacher,
                'suggested_student' => $student,
            ];
        }, $groups);

        return $this->response->success([
            'active_number' => $activeNumber,
            'groups'        => $suggestions,
        ], 'Groups discovered');
    }

    /**
     * Create or update a teacher↔student → group mapping.
     */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'teacher_id' => 'required|integer|exists:teachers,id',
            'student_id' => 'required|integer|exists:students,id',
            'group_jid'  => 'required|string|ends_with:@g.us',
            'group_name' => 'nullable|string|max:255',
            'is_active'  => 'boolean',
        ]);

        // Stamp the group with the active number that owns it (the number that
        // is a member of the group right now). Routing only uses this group
        // while that number is the active session.
        $activeNumber = WasenderSession::fromNumber();

        $group = WhatsappGroup::updateOrCreate(
            [
                'teacher_id'      => $data['teacher_id'],
                'student_id'      => $data['student_id'],
                'whatsapp_number' => $activeNumber,
            ],
            [
                'group_jid'  => $data['group_jid'],
                'group_name' => $data['group_name'] ?? null,
                'is_active'  => $data['is_active'] ?? true,
            ],
        );

        return $this->response->success(
            $group->load(['teacher:id,name', 'student:id,name']),
            'WhatsApp group linked',
        );
    }

    /**
     * Remove a mapping (reminders for that pair revert to private numbers).
     */
    public function destroy(int $id): JsonResponse
    {
        WhatsappGroup::findOrFail($id)->delete();

        return $this->response->success(null, 'WhatsApp group unlinked');
    }

    /**
     * Reduce a phone to comparable digits (drop +, spaces, leading-zero noise).
     */
    private function normalizePhone(string $phone): string
    {
        return preg_replace('/\D/', '', $phone) ?? '';
    }

    /**
     * Add OR-LIKE clauses matching a column's trailing digits against any of
     * the supplied participant phone numbers. Trailing-digit comparison tolerates
     * country-code/format differences between stored and WhatsApp-reported numbers.
     */
    private function matchByDigits($query, string $column, array $digits): void
    {
        $matched = false;
        foreach (array_filter($digits) as $d) {
            $tail = substr($d, -9); // last 9 digits — enough to identify a number
            if ($tail !== '') {
                $query->orWhere($column, 'like', "%{$tail}");
                $matched = true;
            }
        }

        // No usable participant numbers → match nothing (don't fall through to
        // an unconstrained query that would return an arbitrary row).
        if (!$matched) {
            $query->whereRaw('1 = 0');
        }
    }
}
