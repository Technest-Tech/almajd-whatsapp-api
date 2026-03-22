import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../students/data/models/student_model.dart';
import '../../../students/data/student_repository.dart';
import '../../../schedules/data/schedule_repository.dart';
import '../../../schedules/data/models/schedule_model.dart';
import '../../../students/presentation/screens/student_detail_screen.dart';
import '../../../students/presentation/screens/student_schedule_form.dart';
import '../../../teachers/data/models/teacher_model.dart';
import '../../../teachers/data/teacher_repository.dart';

/// Shows ALL student timetable templates fetched from the real API.
class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  List<ScheduleModel> _schedules = [];
  bool _isLoading = true;
  String _searchQuery = '';

  static const _dayNames = [
    'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت',
  ];
  static const _dayColors = [
    Color(0xFF26A69A), Color(0xFF42A5F5), Color(0xFFAB47BC), Color(0xFFEF5350),
    Color(0xFFFF7043), Color(0xFF66BB6A), Color(0xFFFFA726),
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final repo = getIt<ScheduleRepository>();
      final schedules = await repo.getSchedules(perPage: 100);
      if (mounted) {
        setState(() {
          _schedules = schedules;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل تحميل الجداول')),
        );
      }
    }
  }

  List<ScheduleModel> get _filtered {
    if (_searchQuery.isEmpty) return _schedules;
    final q = _searchQuery.toLowerCase();
    return _schedules.where((t) {
      if (t.studentName?.toLowerCase().contains(q) ?? false) return true;
      if (t.name.toLowerCase().contains(q)) return true;
      return t.entries.any((e) =>
          e.title.toLowerCase().contains(q) ||
          (e.teacherName?.toLowerCase().contains(q) ?? false));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final totalEntries = filtered.fold<int>(0, (s, t) => s + t.entryCount);

    return Column(
      children: [
        // ── Search Bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'بحث عن طالب أو جدول...',
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              filled: true,
              fillColor: AppColors.darkCard,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // ── Body ──
        Expanded(
          child: Stack(
            children: [
              _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _searchQuery.isNotEmpty
                                  ? Icons.search_off
                                  : Icons.calendar_month,
                              size: 64,
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'لا توجد نتائج لـ "$_searchQuery"'
                                  : 'لا يوجد جداول مسجلة بعد',
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _loadAll,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: filtered.length + 1, // +1 for the summary badge
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primary.withValues(alpha: 0.15),
                                      AppColors.primary.withValues(alpha: 0.05),
                                    ],
                                    begin: Alignment.topRight,
                                    end: Alignment.bottomLeft,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_month,
                                        color: AppColors.primary, size: 22),
                                    const SizedBox(width: 10),
                                    Text(
                                      '${filtered.length} قالب',
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primary),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '• $totalEntries حصة أسبوعية',
                                      style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13),
                                    ),
                                  ],
                                ),
                              );
                            }
                            // -1 to account for the summary badge
                            final schedule = filtered[index - 1];
                            return _buildScheduleCard(schedule);
                          },
                        ),
                      ),
              // FAB overlay
              Positioned(
                bottom: 16,
                left: 16,
                child: FloatingActionButton.extended(
                  heroTag: 'add_timetable',
                  onPressed: _showAddTimetable,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة جدول'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Schedule Card ────────────────────────────────────────────────

  Widget _buildScheduleCard(ScheduleModel t) {
    final entries = List<ScheduleEntryModel>.from(t.entries)
      ..sort((a, b) {
        final d = a.dayOfWeek.compareTo(b.dayOfWeek);
        return d != 0 ? d : a.startTime.compareTo(b.startTime);
      });

    // Group by day
    final byDay = <int, List<ScheduleEntryModel>>{};
    for (final e in entries) {
      byDay.putIfAbsent(e.dayOfWeek, () => []).add(e);
    }
    final sortedDays = byDay.keys.toList()..sort();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            onTap: () => context.push('/schedules/${t.id}'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      t.studentName != null && t.studentName!.isNotEmpty
                          ? t.studentName![0]
                          : '؟',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.studentName ?? t.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.access_time,
                                size: 12, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              '${t.entryCount} حصة • ${sortedDays.length} أيام أسبوعياً',
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Delete Schedule button
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.coral, size: 22),
                    tooltip: 'حذف التمبلت بالكامل',
                    onPressed: () => _deleteSchedule(t),
                  ),
                ],
              ),
            ),
          ),

          Container(height: 1, color: AppColors.darkCardElevated),

          // ── Compact summary only (details in dedicated screen) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(
              children: [
                const Icon(Icons.list_alt, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${t.entryCount} حصة أسبوعية • ${sortedDays.length} أيام',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/schedules/${t.id}'),
                  icon: const Icon(Icons.chevron_left, size: 18, color: AppColors.primary),
                  label: const Text('عرض التفاصيل', style: TextStyle(color: AppColors.primary)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryTile(
      ScheduleEntryModel entry, Color color, ScheduleModel schedule) {
    final isActive = entry.isActive;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? color.withValues(alpha: 0.08)
            : AppColors.darkCardElevated.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border(
            left: BorderSide(color: isActive ? color : AppColors.textSecondary, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isActive
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 11, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                    const SizedBox(width: 3),
                    Text(
                      '${entry.startTime12h} - ${entry.endTime12h}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                    if (entry.teacherName != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.person_outline, size: 11, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          entry.teacherName!,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Active indicator
          if (!isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('موقوف',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w700)),
            ),
          // Edit button
          IconButton(
            icon: Icon(Icons.edit_outlined,
                size: 16,
                color: isActive ? color : AppColors.textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => _editEntry(entry, schedule),
          ),
        ],
      ),
    );
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  void _showStudentEntries(int studentId) {
    // Kept for backward compatibility (currently unused in the card tap).
    Navigator.of(context).pushNamed('/students/$studentId');
  }

  void _addEntryForStudent(StudentModel student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StudentScheduleForm(
        studentName: student.name,
        onSave: (scheduleName, entries) async {
          final repo = getIt<ScheduleRepository>();
          try {
            final now = DateTime.now();
            final start = DateTime(now.year, now.month, now.day);
            final end = start.add(const Duration(days: 90));
            String fmt(DateTime d) =>
                '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

            // Create the parent schedule with default date range
            final schedule = await repo.createSchedule({
              'student_id': student.id,
              'name': scheduleName,
              'start_date': fmt(start),
              'end_date': fmt(end),
              'is_active': true,
            });
            // Add all entries
            for (final data in entries) {
              await repo.addEntry(schedule.id, data);
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم إنشاء الجدول وإضافة ${entries.length} حصة لـ ${student.name}'),
                  backgroundColor: AppColors.success,
                ),
              );
              _loadAll(); // Refresh
            }
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('فشل إنشاء الجدول'),
                  backgroundColor: AppColors.coral,
                ),
              );
            }
            rethrow; // Inform form that saving failed
          }
        },
      ),
    );
  }

  void _editEntry(ScheduleEntryModel entry, ScheduleModel schedule) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditEntrySheet(
        entry: entry,
        scheduleId: schedule.id,
        onSaved: () {
          _loadAll();
        },
        onDeleted: () {
          Navigator.pop(context);
          _loadAll();
        },
      ),
    );
  }

  void _deleteSchedule(ScheduleModel schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        title: const Text('حذف الجدول بالكامل'),
        content: Text('هل أنت متأكد من حذف الجدول "${schedule.name}"؟ سيتم إلغاء جميع الحصص المستقبلية المرتبطة به.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await getIt<ScheduleRepository>().deleteSchedule(schedule.id);
      if (mounted) _loadAll();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('فشل حذف الجدول'),
              backgroundColor: AppColors.coral),
        );
      }
    }
  }

  void _showAddTimetable() {
    // Show student picker then schedule form
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _StudentPickerSheet(
        onStudentSelected: (student) {
          Navigator.pop(context);
          _addEntryForStudent(student);
        },
      ),
    );
  }
}

// ─── Student Picker Sheet ─────────────────────────────────────────────────────

class _StudentPickerSheet extends StatefulWidget {
  final void Function(StudentModel) onStudentSelected;

  const _StudentPickerSheet({
    required this.onStudentSelected,
  });

  @override
  State<_StudentPickerSheet> createState() => _StudentPickerSheetState();
}

class _StudentPickerSheetState extends State<_StudentPickerSheet> {
  List<StudentModel> _students = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = getIt<StudentRepository>();
      final list = await repo.getStudents(perPage: 100);
      if (mounted) setState(() { _students = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<StudentModel> get _filtered {
    if (_query.isEmpty) return _students;
    final q = _query.toLowerCase();
    return _students.where((s) => s.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.person_add_alt_1, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'اختر طالباً لإنشاء جدول',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'ابحث عن طالب...',
                prefixIcon: const Icon(
                  Icons.search,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.darkBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final s = _filtered[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary,
                        radius: 18,
                        child: Text(
                          s.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(s.name),
                      subtitle: s.whatsappNumber != null
                          ? Text(
                              s.whatsappNumber!,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            )
                          : null,
                      onTap: () => widget.onStudentSelected(s),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Edit Entry Sheet ─────────────────────────────────────────────────────────

class _EditEntrySheet extends StatefulWidget {
  final ScheduleEntryModel entry;
  final int scheduleId;
  final VoidCallback onSaved;
  final VoidCallback onDeleted;

  const _EditEntrySheet({
    required this.entry,
    required this.scheduleId,
    required this.onSaved,
    required this.onDeleted,
  });

  @override
  State<_EditEntrySheet> createState() => _EditEntrySheetState();
}

class _EditEntrySheetState extends State<_EditEntrySheet> {
  late TextEditingController _titleCtrl;
  late bool _isActive;
  late TimeOfDay _start;
  late TimeOfDay _end;
  bool _saving = false;
  
  List<TeacherModel> _teachers = [];
  bool _isLoadingTeachers = true;
  TeacherModel? _selectedTeacher;

  static const _dayNames = [
    'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت',
  ];
  static const _dayColors = [
    Color(0xFF26A69A), Color(0xFF42A5F5), Color(0xFFAB47BC), Color(0xFFEF5350),
    Color(0xFFFF7043), Color(0xFF66BB6A), Color(0xFFFFA726),
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.entry.title);
    _isActive = widget.entry.isActive;
    final sp = widget.entry.startTime.split(':');
    final ep = widget.entry.endTime.split(':');
    _start = TimeOfDay(hour: int.parse(sp[0]), minute: int.parse(sp[1]));
    _end = TimeOfDay(hour: int.parse(ep[0]), minute: int.parse(ep[1]));
    _loadTeachersAndInit();
  }

  Future<void> _loadTeachersAndInit() async {
    try {
      final loadedTeachers = await getIt<TeacherRepository>().getTeachers(perPage: 100) as List<TeacherModel>;
      if (mounted) {
        setState(() {
          _teachers = loadedTeachers;
          _isLoadingTeachers = false;
        });
        
        if (widget.entry.teacherId != null) {
          try {
            setState(() {
              _selectedTeacher = _teachers.firstWhere((t) => t.id == widget.entry.teacherId);
            });
          } catch (_) {}
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingTeachers = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _openTeacherPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = _teachers.where((TeacherModel t) {
              if (searchQuery.isEmpty) return true;
              return t.name.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('اختر المعلم', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      TextField(
                        autofocus: true,
                        onChanged: (v) => setModalState(() => searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'ابحث عن معلم...',
                          prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                          filled: true,
                          fillColor: AppColors.darkBg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_isLoadingTeachers)
                         const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.primary)))
                      else if (filtered.isEmpty)
                         const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('لم يتم العثور على معلمين', style: TextStyle(color: AppColors.textSecondary))))
                      else
                         Expanded(
                           child: ListView.separated(
                             itemCount: filtered.length,
                             separatorBuilder: (_, __) => const SizedBox(height: 8),
                             itemBuilder: (_, i) {
                               final teacher = filtered[i];
                               final isSelected = _selectedTeacher?.id == teacher.id;
                               return InkWell(
                                 onTap: () {
                                   setState(() {
                                     _selectedTeacher = teacher;
                                   });
                                   Navigator.pop(ctx);
                                 },
                                 borderRadius: BorderRadius.circular(10),
                                 child: Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                   decoration: BoxDecoration(
                                     color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.darkBg,
                                     border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent),
                                     borderRadius: BorderRadius.circular(10),
                                   ),
                                   child: Row(
                                     children: [
                                       CircleAvatar(
                                         backgroundColor: AppColors.primary,
                                         radius: 16,
                                         child: const Icon(Icons.person, size: 18, color: Colors.white),
                                       ),
                                       const SizedBox(width: 12),
                                       Expanded(
                                         child: Text(
                                           teacher.name,
                                           style: TextStyle(
                                             fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                             color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                           ),
                                         ),
                                       ),
                                       if (isSelected) const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                                     ],
                                   ),
                                 ),
                               );
                             },
                           ),
                         ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.darkCard,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => isStart ? _start = picked : _end = picked);
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    if (_selectedTeacher == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء اختيار معلم للحصة', style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.coral,
        ),
      );
      return;
    }
    
    setState(() => _saving = true);
    try {
      await getIt<ScheduleRepository>().updateEntry(
        widget.scheduleId,
        widget.entry.id,
        {
          'title': _titleCtrl.text.trim(),
          'start_time': _fmtTime(_start),
          'end_time': _fmtTime(_end),
          'teacher_id': _selectedTeacher?.id,
          'is_active': _isActive,
        },
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم تحديث الحصة بنجاح'),
              backgroundColor: AppColors.success),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('فشل تحديث الحصة'),
              backgroundColor: AppColors.coral),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        title: const Text('حذف الحصة'),
        content: Text('حذف "${widget.entry.title}" من هذا الجدول؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await getIt<ScheduleRepository>()
          .deleteEntry(widget.scheduleId, widget.entry.id);
      if (mounted) widget.onDeleted();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('فشل الحذف'),
              backgroundColor: AppColors.coral),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.entry.dayOfWeek.clamp(0, 6);
    final dayColor = _dayColors[day];
    final dayName = _dayNames[day];

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_calendar, color: dayColor),
              const SizedBox(width: 8),
              const Text('تعديل الحصة',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: dayColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(dayName,
                    style: TextStyle(
                        color: dayColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('المادة / العنوان',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.darkBg,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(height: 16),
          const Text('المعلم', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          InkWell(
            onTap: _openTeacherPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: AppColors.darkBg, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.person, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isLoadingTeachers 
                          ? 'جاري التحميل...' 
                          : (_selectedTeacher?.name ?? 'بدون معلم'),
                      style: TextStyle(
                        color: _selectedTeacher == null ? AppColors.textSecondary : AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('من',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            fontSize: 12)),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _pickTime(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                            color: AppColors.darkBg,
                            borderRadius: BorderRadius.circular(10)),
                        child: Row(children: [
                          Icon(Icons.access_time,
                              size: 16, color: dayColor),
                          const SizedBox(width: 6),
                          Text(_fmtTime(_start),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('إلى',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            fontSize: 12)),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _pickTime(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                            color: AppColors.darkBg,
                            borderRadius: BorderRadius.circular(10)),
                        child: Row(children: [
                          Icon(Icons.access_time,
                              size: 16, color: dayColor),
                          const SizedBox(width: 6),
                          Text(_fmtTime(_end),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
                color: AppColors.darkBg,
                borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('حالة الحصة',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    Text(_isActive ? 'نشطة' : 'موقوفة',
                        style: TextStyle(
                            color: _isActive
                                ? AppColors.success
                                : AppColors.textSecondary,
                            fontSize: 13)),
                    const SizedBox(width: 8),
                    Switch(
                      value: _isActive,
                      activeColor: AppColors.success,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dayColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('حفظ التعديلات',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.coral),
                onPressed: _delete,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.coral.withValues(alpha: 0.1),
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
