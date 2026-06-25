import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../teachers/data/models/teacher_model.dart';
import '../../../teachers/data/teacher_repository.dart';
import '../../../students/data/models/student_model.dart';
import '../../../students/data/student_repository.dart';
import '../../data/admin_repository.dart';

/// Admin screen to map shared WhatsApp groups (that already contain a teacher
/// and a student together) to the teacher↔student pair, so reminders/polls are
/// routed to the group instead of the two private numbers.
///
/// Two tabs:
///   • اكتشاف  — pulls every group the bot is in, pre-fills the suggested
///               teacher + student, and lets the admin confirm each link.
///   • المربوطة — the saved mappings, with an unlink action.
class WhatsAppGroupsScreen extends StatefulWidget {
  const WhatsAppGroupsScreen({super.key});

  @override
  State<WhatsAppGroupsScreen> createState() => _WhatsAppGroupsScreenState();
}

class _WhatsAppGroupsScreenState extends State<WhatsAppGroupsScreen> {
  final _admin = GetIt.instance<AdminRepository>();
  final _teacherRepo = GetIt.instance<TeacherRepository>();
  final _studentRepo = GetIt.instance<StudentRepository>();

  bool _loading = true;
  String? _error;

  List<TeacherModel> _teachers = [];
  List<StudentModel> _students = [];
  List<Map<String, dynamic>> _discovered = [];
  List<Map<String, dynamic>> _linked = [];
  String? _activeNumber;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _teacherRepo.getTeachers(),
        _studentRepo.getStudents(),
        _admin.discoverWhatsAppGroups(),
        _admin.getWhatsAppGroups(),
      ]);
      if (!mounted) return;
      final discoverRes = results[2] as Map<String, dynamic>;
      final linkedRes = results[3] as Map<String, dynamic>;
      setState(() {
        _teachers = results[0] as List<TeacherModel>;
        _students = results[1] as List<StudentModel>;
        _discovered = List<Map<String, dynamic>>.from(discoverRes['groups'] ?? const []);
        _linked = List<Map<String, dynamic>>.from(linkedRes['groups'] ?? const []);
        _activeNumber = (discoverRes['active_number'] ?? linkedRes['active_number']) as String?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذّر تحميل المجموعات. تأكد من اتصال واتساب وحاول مجددًا.';
        _loading = false;
      });
    }
  }

  Future<void> _link({
    required String groupJid,
    required String? groupName,
    required int teacherId,
    required int studentId,
  }) async {
    try {
      await _admin.linkWhatsAppGroup(
        teacherId: teacherId,
        studentId: studentId,
        groupJid: groupJid,
        groupName: groupName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم ربط المجموعة بنجاح')),
      );
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل ربط المجموعة')),
      );
    }
  }

  Future<void> _unlink(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        title: const Text('إلغاء الربط'),
        content: const Text('سيعود إرسال التذكيرات لهذا الطالب والمعلم إلى أرقامهم الخاصة. متابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد', style: TextStyle(color: AppColors.slaRed)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _admin.unlinkWhatsAppGroup(id);
      if (!mounted) return;
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل إلغاء الربط')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('ربط مجموعات واتساب'),
            actions: [
              IconButton(
                tooltip: 'تحديث',
                onPressed: _loading ? null : _loadAll,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(text: 'اكتشاف'),
                Tab(text: 'المربوطة'),
              ],
            ),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _ErrorState(message: _error!, onRetry: _loadAll)
                  : Column(
                      children: [
                        _ActiveNumberBanner(number: _activeNumber),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildDiscoverTab(),
                              _buildLinkedTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  // ── Discover tab ──────────────────────────────────────────────────────────

  Widget _buildDiscoverTab() {
    if (_discovered.isEmpty) {
      return _EmptyState(
        icon: Icons.group_off_rounded,
        message: 'لم يتم العثور على مجموعات.\nتأكد من أن رقم البوت عضو في المجموعات.',
        onRetry: _loadAll,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _discovered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _DiscoverCard(
          key: ValueKey(_discovered[i]['group_jid']),
          group: _discovered[i],
          teachers: _teachers,
          students: _students,
          onLink: _link,
        ),
      ),
    );
  }

  // ── Linked tab ────────────────────────────────────────────────────────────

  Widget _buildLinkedTab() {
    if (_linked.isEmpty) {
      return _EmptyState(
        icon: Icons.link_off_rounded,
        message: 'لا توجد مجموعات مربوطة بعد.',
        onRetry: _loadAll,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _linked.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final g = _linked[i];
          final teacher = (g['teacher'] as Map?)?['name'] ?? '—';
          final student = (g['student'] as Map?)?['name'] ?? '—';
          final name = (g['group_name'] as String?)?.trim();
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.darkCardElevated),
            ),
            child: Row(
              children: [
                const Icon(Icons.groups_rounded, color: AppColors.success),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (name != null && name.isNotEmpty) ? name : 'مجموعة',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'المعلم: $teacher  •  الطالب: $student',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'إلغاء الربط',
                  onPressed: () => _unlink((g['id'] as num).toInt()),
                  icon: const Icon(Icons.link_off_rounded, color: AppColors.slaRed),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Discover card (a single group with teacher/student pickers) ─────────────

class _DiscoverCard extends StatefulWidget {
  final Map<String, dynamic> group;
  final List<TeacherModel> teachers;
  final List<StudentModel> students;
  final Future<void> Function({
    required String groupJid,
    required String? groupName,
    required int teacherId,
    required int studentId,
  }) onLink;

  const _DiscoverCard({
    super.key,
    required this.group,
    required this.teachers,
    required this.students,
    required this.onLink,
  });

  @override
  State<_DiscoverCard> createState() => _DiscoverCardState();
}

class _DiscoverCardState extends State<_DiscoverCard> {
  int? _teacherId;
  int? _studentId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _teacherId = _idFrom(widget.group['suggested_teacher']);
    _studentId = _idFrom(widget.group['suggested_student']);
  }

  int? _idFrom(dynamic obj) {
    if (obj is Map && obj['id'] != null) return (obj['id'] as num).toInt();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final alreadyLinked = widget.group['already_linked'] == true;
    final name = (widget.group['group_name'] as String?)?.trim();
    final canLink = _teacherId != null && _studentId != null && !_saving;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alreadyLinked ? AppColors.success : AppColors.darkCardElevated,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_2_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  (name != null && name.isNotEmpty) ? name : 'مجموعة بدون اسم',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
              if (alreadyLinked)
                const _Chip(text: 'مربوطة', color: AppColors.success),
            ],
          ),
          const SizedBox(height: 12),
          _picker<int>(
            label: 'المعلم',
            value: _teacherId,
            items: widget.teachers
                .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) => setState(() => _teacherId = v),
          ),
          const SizedBox(height: 10),
          _picker<int>(
            label: 'الطالب',
            value: _studentId,
            items: widget.students
                .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) => setState(() => _studentId = v),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canLink ? _submit : null,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(alreadyLinked ? Icons.sync_rounded : Icons.link_rounded, size: 18),
              label: Text(alreadyLinked ? 'تحديث الربط' : 'ربط'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    await widget.onLink(
      groupJid: widget.group['group_jid'] as String,
      groupName: widget.group['group_name'] as String?,
      teacherId: _teacherId!,
      studentId: _studentId!,
    );
    if (mounted) setState(() => _saving = false);
  }

  Widget _picker<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          hint: Text('اختر $label', style: const TextStyle(color: AppColors.textSecondary)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Shows which Wasender number these groups belong to. Groups are tied to the
/// active number — switching the number (from Settings) shows that number's
/// own groups; pairs without a group for the active number fall back to private.
class _ActiveNumberBanner extends StatelessWidget {
  final String? number;
  const _ActiveNumberBanner({required this.number});

  @override
  Widget build(BuildContext context) {
    final n = (number == null || number!.isEmpty) ? 'غير معروف' : number!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.primary.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.smartphone_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'الرقم النشط: $n — تُربط المجموعات بهذا الرقم',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback onRetry;
  const _EmptyState({required this.icon, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 100),
        Icon(icon, size: 56, color: AppColors.textSecondary),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('تحديث'),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.slaRed),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
