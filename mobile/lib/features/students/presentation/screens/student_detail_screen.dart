import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';

import '../../data/models/student_model.dart';
import '../../data/models/class_session_model.dart';
import '../../data/student_repository.dart';
import '../../../schedules/data/schedule_repository.dart'; // Added import
import '../../../schedules/data/models/schedule_model.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/api/api_client.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../widgets/student_classes_tab.dart';
import 'student_schedule_form.dart';
import 'package:go_router/go_router.dart';

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
  bool _isLoading = true;
  bool _sessionsLoaded = false; // tracks whether sessions fetch has completed
  final _apiClient = getIt<ApiClient>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStudent();
  }

  void _loadStudent() async {
    try {
      final repo = getIt<StudentRepository>();
      final results = await Future.wait([
        repo.getStudent(widget.studentId),
        repo.getScheduleEntries(widget.studentId),
      ]);
      if (mounted) {
        setState(() {
          _student = results[0] as StudentModel;
          _scheduleEntries
            ..clear()
            ..addAll(results[1] as List<ScheduleEntryModel>);
          _isLoading = false;
        });
        // Auto-generate class sessions for this month in the background
        _autoGenerateSessions(repo);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل تحميل بيانات الطالب')),
        );
      }
    }
  }

  Future<void> _autoGenerateSessions(StudentRepository repo) async {
    try {
      await repo.generateClassSessions(widget.studentId);
      final sessions = await repo.getClassSessions(widget.studentId);
      if (mounted) {
        setState(() {
          _classSessions.clear();
          for (final s in sessions) {
            try { _classSessions.add(ClassSessionModel.fromJson(s as Map<String, dynamic>)); } catch (_) {}
          }
          _sessionsLoaded = true;
        });
      }
    } catch (e) {
      // Even if generate fails, try to fetch existing sessions
      try {
        final sessions = await repo.getClassSessions(widget.studentId);
        if (mounted) {
          setState(() {
            _classSessions.clear();
            for (final s in sessions) {
              try { _classSessions.add(ClassSessionModel.fromJson(s as Map<String, dynamic>)); } catch (_) {}
            }
            _sessionsLoaded = true;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _sessionsLoaded = true); // stop spinner even on failure
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الطالب')),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_student == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الطالب')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.coral),
              const SizedBox(height: 16),
              const Text('فشل تحميل بيانات الطالب', style: TextStyle(color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _loadStudent();
                },
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    final student = _student!;
    final canEdit = _canEditStudentData();

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الطالب'),
        actions: [
          if (canEdit) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final result = await context.push('/students/${student.id}/edit');
                if (result == true && mounted) {
                  _loadStudent();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.coral),
              onPressed: () => _confirmDelete(context, student),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // ── Profile Header ──
          _buildProfileHeader(student, canEdit: canEdit),

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
                _buildTimelineTab(canEdit: canEdit),
                _buildSessionsTab(),
                _buildNotesTab(student),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _canEditStudentData() {
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        final role = authState.user.primaryRole;
        return role != 'supervisor' && role != 'senior_supervisor';
      }
    } catch (_) {}
    return false;
  }

  Widget _buildProfileHeader(StudentModel student, {required bool canEdit}) {
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
                if (canEdit) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (student.country != null) ...[
                        const Icon(Icons.public_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Text(student.country!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        const SizedBox(width: 12),
                      ],
                      if (student.whatsappNumber != null) ...[
                        const Icon(Icons.chat_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Text(student.whatsappNumber!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        const SizedBox(width: 12),
                      ],
                      const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Text(student.enrollmentDisplay, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildTimelineTab({required bool canEdit}) {
    if (_scheduleEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 12),
            const Text(
              'لا يوجد جدول زمني لهذا الطالب',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 6),
            if (canEdit) ...[
              const Text(
                'اضغط + لإضافة حصة للجدول',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _openScheduleForm,
                icon: const Icon(Icons.add),
                label: const Text('إضافة حصة للجدول'),
              ),
            ],
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
                  ...dayEntries.map((entry) => _buildScheduleEntryTile(entry, dayColor, canEdit: canEdit)),
                  const SizedBox(height: 14),
                ],
              );
            }),
          ],
        ),
        Positioned(
          bottom: 16,
          left: 16,
          child: canEdit
              ? FloatingActionButton.extended(
                  heroTag: 'add_entry',
                  onPressed: _openScheduleForm,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة للجدول'),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildScheduleEntryTile(
    ScheduleEntryModel entry,
    Color dayColor, {
    required bool canEdit,
  }) {
    return Dismissible(
      key: ValueKey('entry_${entry.id}_${entry.title}_${entry.dayOfWeek}'),
      direction: DismissDirection.endToStart,
      background: canEdit
          ? Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.coral,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.white),
            )
          : const SizedBox.shrink(),
      confirmDismiss: canEdit ? null : (_) async => false,
      onDismissed: (_) async {
        if (!canEdit) return;
        setState(() => _scheduleEntries.remove(entry));
        try {
          await getIt<StudentRepository>().deleteScheduleEntry(widget.studentId, entry.id);
        } catch (_) {
          // Restore on error
          if (mounted) setState(() => _scheduleEntries.add(entry));
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم حذف "${entry.title}"'), backgroundColor: AppColors.coral),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(0),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Colored left bar
                Container(width: 6, color: entry.isActive ? dayColor : AppColors.textSecondary),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    child: Row(
                      children: [
                         // Time Column
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(entry.startTime12h, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: entry.isActive ? AppColors.textPrimary : AppColors.textSecondary)),
                            Container(width: 1, height: 16, color: AppColors.darkCardElevated, margin: const EdgeInsets.symmetric(vertical: 4)),
                            Text(entry.endTime12h, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          ],
                        ),
                        const SizedBox(width: 16),
                        // Details Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(entry.title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: entry.isActive ? AppColors.textPrimary : AppColors.textSecondary)),
                                  ),
                                  // Recurrence badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: dayColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                    child: Text(entry.recurrenceDisplay, style: TextStyle(color: dayColor, fontSize: 11, fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                              if (entry.teacherName != null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.person, size: 14, color: AppColors.primary),
                                    const SizedBox(width: 5),
                                    Text(entry.teacherName!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Switch (isActive)
                        if (canEdit)
                          Switch(
                            value: entry.isActive,
                            activeColor: AppColors.primary,
                            onChanged: (val) {
                              _toggleScheduleEntryStatus(entry, val);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleScheduleEntryStatus(ScheduleEntryModel entry, bool isActive) async {
    try {
      // Optimistic UI update
      setState(() {
         final index = _scheduleEntries.indexOf(entry);
         if (index != -1) {
            _scheduleEntries[index] = ScheduleEntryModel(
              id: entry.id,
              title: entry.title,
              dayOfWeek: entry.dayOfWeek,
              startTime: entry.startTime,
              endTime: entry.endTime,
              teacherId: entry.teacherId,
              teacherName: entry.teacherName,
              recurrence: entry.recurrence,
              notes: entry.notes,
              isActive: isActive,
            );
         }
      });
      // Call backend
      await getIt<StudentRepository>().updateScheduleEntry(widget.studentId, entry.id, {'is_active': isActive});
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل تحديث حالة الحصة'), backgroundColor: AppColors.coral));
         _loadStudent(); // reload to revert
      }
    }
  }

  void _openScheduleForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StudentScheduleForm(
        studentName: _student?.name,
        onSave: (scheduleName, entriesData) async {
          try {
            final repo = getIt<ScheduleRepository>();
            final schedule = await repo.createSchedule({
              'student_id': widget.studentId,
              'name': scheduleName,
            });
            for (var data in entriesData) {
              final newEntry = await repo.addEntry(schedule.id, data);
              setState(() {
                 _scheduleEntries.add(newEntry);
              });
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إنشاء الجدول وإضافة ${entriesData.length} حصص بنجاح'), backgroundColor: AppColors.success));
              _loadStudent(); // Refresh the whole student to pick up changes
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل حفظ الجدول'), backgroundColor: AppColors.coral));
            }
            rethrow;
          }
        },
      ),
    );
  }

  Widget _buildSessionsTab() {
    final canEdit = _canEditStudentData();
    if (!_sessionsLoaded) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
            SizedBox(height: 14),
            Text('جارٍ تحميل الحصص...', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    if (_classSessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.class_outlined, size: 64, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 12),
            const Text('لا توجد حصص لهذا الشهر', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('غير موجود جدول زمني أو لم يتم التوليد بعد', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }
    return StudentClassesTab(
      sessions: _classSessions,
      canGenerate: canEdit,
      onGenerate: () async {
        final repo = getIt<StudentRepository>();
        await _autoGenerateSessions(repo);
      },
      onAction: (sessionId, action, {reason, newDate, newStart, newEnd}) {
        // Fire-and-forget: we keep the UI responsive, and refresh from backend after the update.
        _handleSessionAction(
          sessionId,
          action,
          reason: reason,
          newDate: newDate,
          newStart: newStart,
          newEnd: newEnd,
        );
      },
    );
  }

  Future<void> _handleSessionAction(
    int sessionId,
    String action, {
    String? reason,
    DateTime? newDate,
    TimeOfDay? newStart,
    TimeOfDay? newEnd,
  }) async {
    // Optimistic UI update.
    setState(() {
      final idx = _classSessions.indexWhere((s) => s.id == sessionId);
      if (idx == -1) return;
      final old = _classSessions[idx];
      switch (action) {
        case 'complete':
          _classSessions[idx] = ClassSessionModel(
            id: old.id,
            scheduleEntryId: old.scheduleEntryId,
            studentId: old.studentId,
            teacherId: old.teacherId,
            teacherName: old.teacherName,
            title: old.title,
            sessionDate: old.sessionDate,
            startTime: old.startTime,
            endTime: old.endTime,
            status: 'completed',
          );
          break;
        case 'cancel':
          _classSessions[idx] = ClassSessionModel(
            id: old.id,
            scheduleEntryId: old.scheduleEntryId,
            studentId: old.studentId,
            teacherId: old.teacherId,
            teacherName: old.teacherName,
            title: old.title,
            sessionDate: old.sessionDate,
            startTime: old.startTime,
            endTime: old.endTime,
            status: 'cancelled',
            cancellationReason: reason,
          );
          break;
        case 'reschedule':
          if (newDate != null && newStart != null && newEnd != null) {
            String fmtTime(TimeOfDay t) =>
                '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
            _classSessions[idx] = ClassSessionModel(
              id: old.id,
              scheduleEntryId: old.scheduleEntryId,
              studentId: old.studentId,
              teacherId: old.teacherId,
              teacherName: old.teacherName,
              title: old.title,
              sessionDate: old.sessionDate,
              startTime: old.startTime,
              endTime: old.endTime,
              status: 'rescheduled',
              rescheduledDate: newDate,
              rescheduledStartTime: fmtTime(newStart),
              rescheduledEndTime: fmtTime(newEnd),
            );
          }
          break;
      }
    });

    try {
      Map<String, dynamic> payload;
      switch (action) {
        case 'complete':
          payload = {'status': 'completed'};
          break;
        case 'cancel':
          payload = {'status': 'cancelled'};
          if (reason != null && reason.trim().isNotEmpty) {
            payload['cancellation_reason'] = reason.trim();
          }
          break;
        case 'reschedule':
          payload = {'status': 'rescheduled'};
          if (newDate != null && newStart != null && newEnd != null) {
            final dateStr =
                '${newDate.year}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}';
            String fmtTime(TimeOfDay t) =>
                '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
            payload['rescheduled_date'] = dateStr;
            payload['rescheduled_start_time'] = fmtTime(newStart);
            payload['rescheduled_end_time'] = fmtTime(newEnd);
          }
          break;
        default:
          return;
      }

      await _apiClient.dio.put('/sessions/$sessionId/status', data: payload);

      // Refresh sessions from backend (reverts optimistic UI if needed).
      final repo = getIt<StudentRepository>();
      final sessions = await repo.getClassSessions(widget.studentId);
      if (!mounted) return;
      setState(() {
        _classSessions
          ..clear()
          ..addAll(
            sessions.map((s) => ClassSessionModel.fromJson(s as Map<String, dynamic>)).toList(),
          );
        _sessionsLoaded = true;
      });

      final msg = action == 'complete'
          ? 'تم إتمام الحصة'
          : action == 'cancel'
              ? 'تم إلغاء الحصة'
              : 'تم إعادة جدولة الحصة';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحديث حالة الحصة'), backgroundColor: AppColors.coral),
      );
      // Reload to ensure UI matches backend.
      try {
        final repo = getIt<StudentRepository>();
        final sessions = await repo.getClassSessions(widget.studentId);
        if (!mounted) return;
        setState(() {
          _classSessions
            ..clear()
            ..addAll(
              sessions.map((s) => ClassSessionModel.fromJson(s as Map<String, dynamic>)).toList(),
            );
          _sessionsLoaded = true;
        });
      } catch (_) {}
    }
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
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                await getIt<StudentRepository>().deleteStudent(student.id);
                if (mounted) {
                  Navigator.pop(context, true); // True signals to refresh the list
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم حذف الطالب'), backgroundColor: AppColors.coral),
                  );
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('فشل حذف الطالب'), backgroundColor: AppColors.coral),
                  );
                }
              }
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

}
