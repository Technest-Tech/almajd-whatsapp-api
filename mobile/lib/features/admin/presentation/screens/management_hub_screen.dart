import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/api_service.dart';
import '../../../teachers/data/models/teacher_model.dart';
import '../../../teachers/data/teacher_repository.dart';

class ManagementHubScreen extends StatefulWidget {
  const ManagementHubScreen({super.key});

  @override
  State<ManagementHubScreen> createState() => _ManagementHubScreenState();
}

class _ManagementHubScreenState extends State<ManagementHubScreen> {
  static const _items = [
    _HubItem(icon: Icons.calendar_today_rounded, label: 'التقويم', subtitle: 'الجدول والتذكيرات', path: '/calendar', color: Color(0xFF2196F3)),
    _HubItem(icon: Icons.calendar_month_rounded, label: 'الجداول', subtitle: 'إدارة جداول الطلاب', path: '/timetable', color: Color(0xFF26A69A)),
    _HubItem(icon: Icons.event_available_rounded, label: 'إدارة الحصص', subtitle: 'والمتابعة', path: '/classes', color: Color(0xFF42A5F5)),
    _HubItem(icon: Icons.shield_rounded, label: 'المشرفون', subtitle: 'إدارة المشرفين', path: '/supervisors', color: Color(0xFFAB47BC)),
    _HubItem(icon: Icons.insert_chart_outlined_rounded, label: 'أداء المشرفين', subtitle: 'التقارير والإحصائيات', path: '/supervisors_stats', color: Color(0xFF00A884)),
    _HubItem(icon: Icons.bar_chart_rounded, label: 'التقارير', subtitle: 'إحصائيات النظام', path: '/analytics', color: Color(0xFFEF5350)),
    _HubItem(icon: Icons.forum_rounded, label: 'ربط مجموعات واتساب', subtitle: 'ربط المجموعات بالمعلمين والطلاب', path: '/whatsapp-groups', color: Color(0xFF25D366)),
    _HubItem(icon: Icons.settings_rounded, label: 'إعدادات النظام', subtitle: 'الحساب والتفضيلات', path: '/settings', color: Color(0xFF78909C)),
  ];

  // ── Session Management State ─────────────────────────────────────────────
  bool _isGenerating = false;
  bool _isClearing = false;
  String? _lastAction;
  DateTime? _lastGeneratedAt;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary.withValues(alpha: 0.25), AppColors.darkCard],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.dashboard_rounded, size: 28, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('لوحة الإدارة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    SizedBox(height: 4),
                    Text('إدارة جميع موارد الأكاديمية', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Navigation Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.15,
          ),
          itemCount: _items.length,
          itemBuilder: (context, index) {
            final item = _items[index];
            return _HubCard(item: item, onTap: () => context.go(item.path));
          },
        ),

        const SizedBox(height: 20),

        // ── Session Management Card ──────────────────────────────────────────
        _buildSessionManagementCard(context),

        const SizedBox(height: 16),

        // ── Reminder Pause Card ──────────────────────────────────────────────
        _buildReminderPauseCard(context),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSessionManagementCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_month_rounded, size: 22, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('إدارة الجلسات', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      Text('توليد أو حذف جلسات التقويم', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (_lastGeneratedAt != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'آخر توليد ${_lastGeneratedAt!.hour.toString().padLeft(2, '0')}:${_lastGeneratedAt!.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),

            // Success status message
            if (_lastAction != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_lastAction!, style: const TextStyle(fontSize: 12, color: Colors.green)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Action Buttons Row
            Row(
              children: [
                // Generate Sessions
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_isGenerating || _isClearing) ? null : () => _generateSessions(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isGenerating
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      _isGenerating ? 'جاري التوليد...' : 'توليد الجلسات\n(3 أشهر)',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Clear All Sessions
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_isGenerating || _isClearing) ? null : () => _confirmClear(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isClearing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                        : const Icon(Icons.delete_sweep_rounded, size: 18),
                    label: Text(
                      _isClearing ? 'جاري الحذف...' : 'حذف جميع\nالجلسات',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderPauseCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.notifications_paused_rounded, size: 22, color: Colors.orange),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('إيقاف التذكيرات', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      Text('إيقاف مؤقت لتذكيرات معلم أثناء الإجازة', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openReminderPauseDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.withValues(alpha: 0.15),
                  foregroundColor: Colors.orange,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.orange.withValues(alpha: 0.4)),
                  ),
                ),
                icon: const Icon(Icons.manage_accounts_rounded, size: 18),
                label: const Text('إدارة إيقاف التذكيرات', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openReminderPauseDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (ctx) => const _ReminderPauseDialog(),
    );
  }

  Future<void> _generateSessions(BuildContext context) async {
    final selectedStudents = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => const _GenerateSessionsDialog(),
    );

    if (selectedStudents == null || !mounted) return;

    setState(() { _isGenerating = true; _lastAction = null; });
    try {
      final api = ApiService();
      final payload = selectedStudents.isNotEmpty ? {'student_names': selectedStudents} : null;
      final response = await api.post('/v1/calendar/sessions/generate', data: payload);
      final responseData = response.data as Map<String, dynamic>?;
      final created = responseData?['sessions_created'] ?? 0;
      final total = responseData?['total_sessions'] ?? 0;
      if (mounted) {
        setState(() {
          _lastAction = 'تم توليد $created جلسة جديدة — الإجمالي: $total';
          _lastGeneratedAt = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل التوليد: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف', textAlign: TextAlign.right),
        content: const Text(
          'سيتم حذف جميع الجلسات القادمة والتذكيرات المعلقة.\nلا يمكن التراجع عن هذا الإجراء.',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف الكل', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() { _isClearing = true; _lastAction = null; });
    try {
      final api = ApiService();
      final response = await api.delete('/v1/calendar/sessions/clear-all');
      final data = response.data as Map<String, dynamic>;
      final deleted = data['deleted_sessions'] ?? 0;
      final reminders = data['deleted_reminders'] ?? 0;
      if (mounted) {
        setState(() {
          _lastAction = 'تم حذف $deleted جلسة و $reminders تذكير';
          _lastGeneratedAt = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحذف: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }
}

class _HubItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final String path;
  final Color color;

  const _HubItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.path,
    required this.color,
  });
}

class _HubCard extends StatelessWidget {
  final _HubItem item;
  final VoidCallback onTap;

  const _HubCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: item.color.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, size: 26, color: item.color),
              ),
              const Spacer(),
              Text(
                item.label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                item.subtitle,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenerateSessionsDialog extends StatefulWidget {
  const _GenerateSessionsDialog();

  @override
  State<_GenerateSessionsDialog> createState() => _GenerateSessionsDialogState();
}

class _GenerateSessionsDialogState extends State<_GenerateSessionsDialog> {
  bool _isLoading = true;
  List<String> _allStudents = [];
  List<String> _filteredStudents = [];
  final List<String> _selectedStudents = [];
  bool _generateForAll = true;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    try {
      final api = ApiService();
      final response = await api.get('/v1/calendar/students/list');
      if (response.data != null && response.data['students'] != null) {
        final students = List<String>.from(response.data['students']);
        if (mounted) {
          setState(() {
            _allStudents = students;
            _filteredStudents = students;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filter(String query) {
    setState(() {
      _filteredStudents = _allStudents
          .where((s) => s.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('خيارات التوليد', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RadioListTile<bool>(
              title: const Text('لجميع الطلاب', style: TextStyle(fontSize: 14)),
              value: true,
              groupValue: _generateForAll,
              onChanged: (val) => setState(() => _generateForAll = val!),
              contentPadding: EdgeInsets.zero,
            ),
            RadioListTile<bool>(
              title: const Text('لطلاب محددين', style: TextStyle(fontSize: 14)),
              value: false,
              groupValue: _generateForAll,
              onChanged: (val) => setState(() => _generateForAll = val!),
              contentPadding: EdgeInsets.zero,
            ),
            if (!_generateForAll) ...[
              const SizedBox(height: 10),
              TextField(
                decoration: InputDecoration(
                  hintText: 'ابحث عن طالب...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                ),
                onChanged: _filter,
              ),
              const SizedBox(height: 10),
              if (_isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
              else
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredStudents.length,
                      itemBuilder: (context, index) {
                        final student = _filteredStudents[index];
                        final isSelected = _selectedStudents.contains(student);
                        return CheckboxListTile(
                          title: Text(student, style: const TextStyle(fontSize: 13)),
                          value: isSelected,
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedStudents.add(student);
                              } else {
                                _selectedStudents.remove(student);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          onPressed: (!_generateForAll && _selectedStudents.isEmpty)
              ? null
              : () {
                  Navigator.pop(
                    context,
                    _generateForAll ? <String>[] : _selectedStudents,
                  );
                },
          child: const Text('تأكيد وتوليد'),
        ),
      ],
    );
  }
}

// ── Reminder Pause Dialog ──────────────────────────────────────────────────

class _ReminderPauseDialog extends StatefulWidget {
  const _ReminderPauseDialog();

  @override
  State<_ReminderPauseDialog> createState() => _ReminderPauseDialogState();
}

class _ReminderPauseDialogState extends State<_ReminderPauseDialog> {
  final _repo = GetIt.instance<TeacherRepository>();

  bool _isLoading = true;
  bool _isActing = false;
  List<TeacherModel> _teachers = [];
  List<TeacherModel> _filtered = [];
  final Set<int> _selected = {};
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final teachers = await _repo.getTeachers();
      teachers.sort((a, b) {
        // Paused teachers first
        if (a.remindersPaused && !b.remindersPaused) return -1;
        if (!a.remindersPaused && b.remindersPaused) return 1;
        return a.name.compareTo(b.name);
      });
      if (mounted) {
        setState(() {
          _teachers = teachers;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    _filtered = _search.isEmpty
        ? List.of(_teachers)
        : _teachers.where((t) => t.name.toLowerCase().contains(_search.toLowerCase())).toList();
  }

  Future<void> _act(bool pause) async {
    if (_selected.isEmpty) return;
    setState(() => _isActing = true);
    try {
      for (final id in _selected) {
        final updated = pause ? await _repo.pauseReminders(id) : await _repo.resumeReminders(id);
        final idx = _teachers.indexWhere((t) => t.id == id);
        if (idx != -1) _teachers[idx] = updated;
      }
      _teachers.sort((a, b) {
        if (a.remindersPaused && !b.remindersPaused) return -1;
        if (!a.remindersPaused && b.remindersPaused) return 1;
        return a.name.compareTo(b.name);
      });
      if (mounted) {
        setState(() {
          _selected.clear();
          _applyFilter();
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(pause ? 'تم إيقاف التذكيرات للمعلمين المحددين' : 'تم استئناف التذكيرات للمعلمين المحددين'),
          backgroundColor: pause ? Colors.orange : Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final anyPausedSelected = _selected.any((id) => _teachers.firstWhere((t) => t.id == id).remindersPaused);
    final anyActiveSelected = _selected.any((id) => !_teachers.firstWhere((t) => t.id == id).remindersPaused);
    final pausedCount = _teachers.where((t) => t.remindersPaused).length;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.notifications_paused_rounded, color: Colors.orange, size: 22),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('إدارة إيقاف التذكيرات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          if (pausedCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: Text('$pausedCount موقوف', style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'ابحث عن معلم...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              ),
              onChanged: (v) => setState(() { _search = v; _applyFilter(); }),
            ),
            const SizedBox(height: 10),
            if (_isLoading)
              const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())
            else
              Flexible(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: _filtered.isEmpty
                      ? const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('لا يوجد معلمون')))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _filtered.length,
                          itemBuilder: (ctx, i) {
                            final t = _filtered[i];
                            final isSelected = _selected.contains(t.id);
                            return CheckboxListTile(
                              value: isSelected,
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                              onChanged: (val) => setState(() {
                                if (val == true) _selected.add(t.id);
                                else _selected.remove(t.id);
                              }),
                              title: Row(
                                children: [
                                  Expanded(child: Text(t.name, style: const TextStyle(fontSize: 13))),
                                  if (t.remindersPaused)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                                      ),
                                      child: const Text('موقوف', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w600)),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
            if (_selected.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('تم تحديد ${_selected.length} معلم', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isActing ? null : () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
        if (anyPausedSelected)
          ElevatedButton.icon(
            onPressed: _isActing ? null : () => _act(false),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            icon: _isActing
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.play_circle_outline_rounded, size: 16),
            label: const Text('استئناف', style: TextStyle(fontSize: 13)),
          ),
        if (anyActiveSelected)
          ElevatedButton.icon(
            onPressed: _isActing ? null : () => _act(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            icon: _isActing
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.pause_circle_outline_rounded, size: 16),
            label: const Text('إيقاف', style: TextStyle(fontSize: 13)),
          ),
      ],
    );
  }
}
