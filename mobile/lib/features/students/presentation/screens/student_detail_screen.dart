import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/student_model.dart';
import '../../data/models/class_session_model.dart';
import '../../../schedules/data/models/schedule_model.dart';
import '../widgets/student_classes_tab.dart';
import 'single_class_session_form.dart';

class StudentDetailScreen extends StatefulWidget {
  final int studentId;
  const StudentDetailScreen({super.key, required this.studentId});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  StudentModel? _student;
  final List<ScheduleEntryModel> _scheduleEntries = [];
  final List<ClassSessionModel> _classSessions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStudent();
  }

  void _loadStudent() {
    if (AuthBloc.demoMode) {
      final mockStudents = _demoStudents();
      final found = mockStudents.where((s) => s.id == widget.studentId);
      if (found.isNotEmpty) {
        setState(() {
          _student = found.first;
          _scheduleEntries.addAll(_demoScheduleEntries());
          // Auto-generate this month's class sessions
          _classSessions.addAll(_demoClassSessions());
        });
      }
    }
  }

  List<ScheduleEntryModel> _demoScheduleEntries() {
    return [
      ScheduleEntryModel(id: 1, scheduleId: null, teacherName: 'أ. عبدالله المحمد', title: 'القرآن الكريم', dayOfWeek: 0, startTime: '08:00', endTime: '09:00', recurrence: 'weekly'),
      ScheduleEntryModel(id: 2, scheduleId: null, teacherName: 'أ. فاطمة الأحمد', title: 'الرياضيات', dayOfWeek: 0, startTime: '09:30', endTime: '10:30', recurrence: 'weekly'),
      ScheduleEntryModel(id: 3, scheduleId: null, teacherName: 'أ. خالد العتيبي', title: 'اللغة العربية', dayOfWeek: 1, startTime: '08:00', endTime: '09:00', recurrence: 'weekly'),
      ScheduleEntryModel(id: 4, scheduleId: null, teacherName: 'أ. نورة السعيد', title: 'العلوم', dayOfWeek: 2, startTime: '10:00', endTime: '11:00', recurrence: 'weekly'),
    ];
  }

  List<ClassSessionModel> _demoClassSessions() {
    final now = DateTime.now();
    final sessions = <ClassSessionModel>[];
    int id = 100;
    for (final entry in _scheduleEntries) {
      // Generate sessions for current month
      var date = DateTime(now.year, now.month, 1);
      while (date.month == now.month) {
        if (date.weekday % 7 == entry.dayOfWeek) {
          final status = date.isBefore(now) ? 'completed' : 'scheduled';
          sessions.add(ClassSessionModel(
            id: id++,
            scheduleEntryId: entry.id,
            studentId: widget.studentId,
            teacherName: entry.teacherName,
            title: entry.title,
            sessionDate: date,
            startTime: entry.startTime,
            endTime: entry.endTime,
            status: status,
          ));
        }
        date = date.add(const Duration(days: 1));
      }
    }
    sessions.sort((a, b) => a.sessionDate.compareTo(b.sessionDate));
    return sessions;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_student == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الطالب')),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final student = _student!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الطالب'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              // Navigate to edit form
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.coral),
            onPressed: () => _confirmDelete(context, student),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Profile Header ──
          _buildProfileHeader(student),

          // ── Guardian Info ──
          if (student.guardianName != null) _buildGuardianSection(student),

          // ── Tabs ──
          Container(
            color: AppColors.darkCard,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              tabs: const [
                Tab(text: 'الجدول الزمني', icon: Icon(Icons.timeline, size: 18)),
                Tab(text: 'الحصص', icon: Icon(Icons.class_outlined, size: 18)),
                Tab(text: 'ملاحظات', icon: Icon(Icons.note_alt_outlined, size: 18)),
              ],
            ),
          ),

          // ── Tab Content ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTimelineTab(),
                _buildSessionsTab(),
                _buildNotesTab(student),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(StudentModel student) {
    final statusColor = _statusColor(student.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.darkSurface, AppColors.darkBg],
        ),
      ),
      child: Row(
        children: [
          // Small avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary,
            child: Text(student.initials, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 14),

          // Name + info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(student.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                      child: Text(student.statusDisplay, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (student.phone != null) ...[
                      const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Text(student.phone!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(width: 12),
                    ],
                    const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 3),
                    Text(student.enrollmentDisplay, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuardianSection(StudentModel student) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkCardElevated),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.family_restroom, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('ولي الأمر', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 14)),
              if (student.guardianRelation != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(student.guardianRelation!, style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(student.guardianName!, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            ],
          ),
          if (student.guardianPhone != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(student.guardianPhone!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineTab() {
    if (_scheduleEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 12),
            const Text('الطالب غير مسجل في أي حصة', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openScheduleForm,
              icon: const Icon(Icons.add),
              label: const Text('إضافة حصة'),
            ),
          ],
        ),
      );
    }

    final entriesByDay = <int, List<ScheduleEntryModel>>{};
    for (final entry in _scheduleEntries) {
      entriesByDay.putIfAbsent(entry.dayOfWeek, () => []).add(entry);
    }
    final sortedDays = entriesByDay.keys.toList()..sort();

    const dayColors = [
      Color(0xFF26A69A), Color(0xFF42A5F5), Color(0xFFAB47BC), Color(0xFFEF5350),
      Color(0xFFFF7043), Color(0xFF66BB6A), Color(0xFFFFA726),
    ];

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            // Timetable record header
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.primary.withValues(alpha: 0.05)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_month, size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text('الجدول الأسبوعي', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primary)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${_scheduleEntries.length} حصة', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('${sortedDays.length} أيام في الأسبوع', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            ...sortedDays.map((day) {
              final dayEntries = entriesByDay[day]!;
              final dayName = dayEntries.first.dayDisplay;
              final dayColor = (day >= 0 && day < dayColors.length) ? dayColors[day] : AppColors.primary;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: dayColor, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(dayName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: dayColor)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: dayColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                        child: Text('${dayEntries.length}', style: TextStyle(color: dayColor, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Container(height: 1, color: dayColor.withValues(alpha: 0.15))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...dayEntries.map((entry) => _buildScheduleEntryTile(entry, dayColor)),
                  const SizedBox(height: 14),
                ],
              );
            }),
          ],
        ),
        Positioned(
          bottom: 16,
          left: 16,
          child: FloatingActionButton.extended(
            heroTag: 'add_entry',
            onPressed: _openScheduleForm,
            icon: const Icon(Icons.add),
            label: const Text('إضافة حصة'),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleEntryTile(ScheduleEntryModel entry, Color dayColor) {
    return Dismissible(
      key: ValueKey('entry_${entry.id}_${entry.title}_${entry.dayOfWeek}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.coral,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) {
        setState(() => _scheduleEntries.remove(entry));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حذف "${entry.title}"'), backgroundColor: AppColors.coral),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(10),
          border: Border(right: BorderSide(color: dayColor, width: 3)),
        ),
        child: Row(
          children: [
            Column(
              children: [
                Text(entry.startTime, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                Container(width: 1, height: 12, color: AppColors.darkCardElevated),
                Text(entry.endTime, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
                  if (entry.teacherName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline, size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(entry.teacherName!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Recurrence badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: dayColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(entry.recurrenceDisplay, style: TextStyle(color: dayColor, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _openScheduleForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SingleClassSessionForm(
        onSave: (data) {
          setState(() {
            _classSessions.add(ClassSessionModel(
              id: DateTime.now().millisecondsSinceEpoch,
              scheduleEntryId: null, // Custom single session, no weekly link
              studentId: widget.studentId,
              teacherName: data['teacher_name'] as String?,
              title: data['title'] as String,
              sessionDate: data['session_date'] as DateTime,
              startTime: data['start_time'] as String,
              endTime: data['end_time'] as String,
              status: 'scheduled',
            ));
            // Sort sessions to keep timeline ordered
            _classSessions.sort((a, b) => a.sessionDate.compareTo(b.sessionDate));
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إضافة الحصة بنجاح'),
              backgroundColor: AppColors.success,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSessionsTab() {
    return StudentClassesTab(
      sessions: _classSessions,
      onGenerate: () {
        setState(() {
          _classSessions.clear();
          _classSessions.addAll(_demoClassSessions());
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم توليد ${_classSessions.length} حصة لهذا الشهر'), backgroundColor: AppColors.success),
        );
      },
      onAction: (sessionId, action, {reason, newDate, newStart, newEnd}) {
        setState(() {
          final idx = _classSessions.indexWhere((s) => s.id == sessionId);
          if (idx == -1) return;
          final old = _classSessions[idx];
          switch (action) {
            case 'complete':
              _classSessions[idx] = ClassSessionModel(
                id: old.id, scheduleEntryId: old.scheduleEntryId, studentId: old.studentId,
                teacherId: old.teacherId, teacherName: old.teacherName, title: old.title,
                sessionDate: old.sessionDate, startTime: old.startTime, endTime: old.endTime,
                status: 'completed',
              );
              break;
            case 'cancel':
              _classSessions[idx] = ClassSessionModel(
                id: old.id, scheduleEntryId: old.scheduleEntryId, studentId: old.studentId,
                teacherId: old.teacherId, teacherName: old.teacherName, title: old.title,
                sessionDate: old.sessionDate, startTime: old.startTime, endTime: old.endTime,
                status: 'cancelled', cancellationReason: reason,
              );
              break;
            case 'reschedule':
              if (newDate != null && newStart != null && newEnd != null) {
                String fmtTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                _classSessions[idx] = ClassSessionModel(
                  id: old.id, scheduleEntryId: old.scheduleEntryId, studentId: old.studentId,
                  teacherId: old.teacherId, teacherName: old.teacherName, title: old.title,
                  sessionDate: old.sessionDate, startTime: old.startTime, endTime: old.endTime,
                  status: 'rescheduled', rescheduledDate: newDate,
                  rescheduledStartTime: fmtTime(newStart), rescheduledEndTime: fmtTime(newEnd),
                );
              }
              break;
          }
        });
        final msg = action == 'complete' ? 'تم إتمام الحصة' : action == 'cancel' ? 'تم إلغاء الحصة' : 'تم إعادة جدولة الحصة';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.success),
        );
      },
    );
  }

  Widget _buildNotesTab(StudentModel student) {
    if (student.notes == null || student.notes!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.note_alt_outlined, size: 64, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 12),
            const Text('لا توجد ملاحظات', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sticky_note_2_outlined, size: 16, color: AppColors.amber),
                  const SizedBox(width: 6),
                  const Text('ملاحظة', style: TextStyle(color: AppColors.amber, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              Text(student.notes!, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, StudentModel student) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        title: const Text('تأكيد الحذف'),
        content: Text('هل تريد حذف الطالب "${student.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم حذف الطالب'), backgroundColor: AppColors.coral),
              );
            },
            child: const Text('حذف', style: TextStyle(color: AppColors.coral)),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return AppColors.success;
      case 'inactive':
        return AppColors.textSecondary;
      case 'suspended':
        return AppColors.coral;
      default:
        return AppColors.textSecondary;
    }
  }

  List<StudentModel> _demoStudents() {
    final now = DateTime.now();
    return [
      StudentModel(id: 1, name: 'يوسف أحمد العلي', phone: '+966501112233', status: 'active', guardianName: 'أحمد العلي', guardianPhone: '+966501112200', guardianRelation: 'أب', enrollmentDate: now.subtract(const Duration(days: 180)), notes: 'طالب متميز في القرآن الكريم', createdAt: now.subtract(const Duration(days: 180)), updatedAt: now.subtract(const Duration(days: 2))),
      StudentModel(id: 2, name: 'سارة محمد القحطاني', phone: '+966502223344', status: 'active', guardianName: 'محمد القحطاني', guardianPhone: '+966502223300', guardianRelation: 'أب', enrollmentDate: now.subtract(const Duration(days: 120)), createdAt: now.subtract(const Duration(days: 120)), updatedAt: now.subtract(const Duration(days: 5))),
      StudentModel(id: 3, name: 'عبدالله خالد السعيد', phone: '+966503334455', status: 'active', guardianName: 'خالد السعيد', guardianPhone: '+966503334400', guardianRelation: 'أب', enrollmentDate: now.subtract(const Duration(days: 90)), notes: 'يحتاج متابعة في الرياضيات', createdAt: now.subtract(const Duration(days: 90)), updatedAt: now.subtract(const Duration(days: 1))),
      StudentModel(id: 4, name: 'لمى عبدالرحمن الدوسري', phone: '+966504445566', status: 'inactive', guardianName: 'نورة القحطاني', guardianPhone: '+966504445500', guardianRelation: 'أم', enrollmentDate: now.subtract(const Duration(days: 365)), notes: 'انسحبت مؤقتاً', createdAt: now.subtract(const Duration(days: 365)), updatedAt: now.subtract(const Duration(days: 30))),
      StudentModel(id: 5, name: 'ريان أحمد الشمري', phone: '+966505556677', status: 'active', guardianName: 'أحمد الشمري', guardianPhone: '+966505556600', guardianRelation: 'أب', enrollmentDate: now.subtract(const Duration(days: 60)), createdAt: now.subtract(const Duration(days: 60)), updatedAt: now.subtract(const Duration(days: 3))),
      StudentModel(id: 6, name: 'عمر هشام الحربي', phone: '+966506667788', status: 'suspended', guardianName: 'هند الدوسري', guardianPhone: '+966506667700', guardianRelation: 'أم', enrollmentDate: now.subtract(const Duration(days: 200)), notes: 'موقوف بسبب عدم السداد', createdAt: now.subtract(const Duration(days: 200)), updatedAt: now.subtract(const Duration(days: 7))),
      StudentModel(id: 7, name: 'نوف سعد المالكي', phone: '+966507778899', status: 'active', guardianName: 'سعد المالكي', guardianPhone: '+966507778800', guardianRelation: 'أب', enrollmentDate: now.subtract(const Duration(days: 45)), createdAt: now.subtract(const Duration(days: 45)), updatedAt: now),
      StudentModel(id: 8, name: 'فيصل ناصر العتيبي', phone: '+966508889900', status: 'active', guardianName: 'ناصر العتيبي', guardianPhone: '+966508889900', guardianRelation: 'أب', enrollmentDate: now.subtract(const Duration(days: 30)), notes: 'مسجل في دورة التجويد', createdAt: now.subtract(const Duration(days: 30)), updatedAt: now.subtract(const Duration(hours: 6))),
    ];
  }
}
