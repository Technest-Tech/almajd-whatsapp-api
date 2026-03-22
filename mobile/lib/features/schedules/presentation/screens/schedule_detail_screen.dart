import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../data/models/schedule_model.dart';
import '../../data/schedule_repository.dart';
import '../screens/schedule_form_screen.dart';
import '../../data/models/schedule_model.dart';
import '../../data/schedule_repository.dart';
import '../../../students/data/models/class_session_model.dart';
import '../../../students/presentation/screens/student_schedule_form.dart';

class ScheduleDetailScreen extends StatefulWidget {
  final int scheduleId;
  const ScheduleDetailScreen({super.key, required this.scheduleId});

  @override
  State<ScheduleDetailScreen> createState() => _ScheduleDetailScreenState();
}

class _ScheduleDetailScreenState extends State<ScheduleDetailScreen> {
  ScheduleModel? _schedule;
  bool _loading = true;
  List<ClassSessionModel> _sessions = [];
  bool _loadingSessions = true;

  static const _dayColors = [
    Color(0xFF26A69A), // Sunday
    Color(0xFF42A5F5), // Monday
    Color(0xFFAB47BC), // Tuesday
    Color(0xFFEF5350), // Wednesday
    Color(0xFFFF7043), // Thursday
    Color(0xFF66BB6A), // Friday
    Color(0xFFFFA726), // Saturday
  ];

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _loading = true;
      _loadingSessions = true;
    });
    try {
      final repo = getIt<ScheduleRepository>();
      final schedule = await repo.getSchedule(widget.scheduleId);
      final sessions = await repo.getScheduleSessions(widget.scheduleId);
      if (!mounted) return;
      setState(() {
        _schedule = schedule;
        _sessions = sessions;
        _loading = false;
        _loadingSessions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingSessions = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل تحميل البيانات'),
          backgroundColor: AppColors.coral,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _schedule == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الجدول')),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final schedule = _schedule!;
    final entriesByDay = <int, List<ScheduleEntryModel>>{};
    for (final entry in schedule.entries) {
      entriesByDay.putIfAbsent(entry.dayOfWeek, () => []).add(entry);
    }
    final sortedDays = entriesByDay.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الجدول'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _openEditScheduleSheet(schedule),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Schedule Header ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary.withValues(alpha: 0.2), AppColors.darkCard],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        schedule.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (schedule.isActive ? AppColors.success : AppColors.textSecondary).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        schedule.statusDisplay,
                        style: TextStyle(
                          color: schedule.isActive ? AppColors.success : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (schedule.description != null) ...[
                  const SizedBox(height: 8),
                  Text(schedule.description!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.date_range, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(schedule.dateRangeDisplay, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const Spacer(),
                    const Icon(Icons.list_alt, size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text('${schedule.entryCount} حصة', style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Day-grouped Entries ──
          if (schedule.entries.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(
                  children: [
                    Icon(Icons.event_busy, size: 64, color: Colors.white.withValues(alpha: 0.15)),
                    const SizedBox(height: 12),
                    const Text('لا توجد حصص في هذا الجدول', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            )
          else
            ...sortedDays.map((day) {
              final dayEntries = entriesByDay[day]!;
              final dayName = dayEntries.first.dayDisplay;
              final dayColor = (day >= 0 && day < _dayColors.length) ? _dayColors[day] : AppColors.primary;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day header
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: dayColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dayName,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: dayColor),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Container(height: 1, color: dayColor.withValues(alpha: 0.2))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Entries
                  ...dayEntries.map((entry) => _buildEntryTile(entry, dayColor)),
                  const SizedBox(height: 16),
                ],
              );
            }),

          // Incoming Classes Section
          const SizedBox(height: 16),
          const Text(
            'الحصص القادمة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          if (_loadingSessions)
            const Center(child: CircularProgressIndicator(color: AppColors.primary))
          else if (_sessions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('لا توجد حصص قادمة', style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7))),
              ),
            )
          else
            ..._sessions.map((session) => _buildSessionTile(session)),
        ],
      ),
    );
  }

  void _openEditScheduleSheet(ScheduleModel schedule) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StudentScheduleForm(
        studentName: schedule.studentName,
        existingSchedule: schedule,
        onSave: (scheduleName, entries) async {
          final repo = getIt<ScheduleRepository>();
          try {
            // Update basic info
            await repo.updateSchedule(schedule.id, {
               'name': scheduleName,
               'description': schedule.description,
               'is_active': schedule.isActive,
            });

            // To support completely editing entries smoothly, we delete old and insert new. 
            // Depending on backend, a single update endpoint could be used, but standard REST usually requires this:
            for (final oldEntry in schedule.entries) {
               await repo.deleteEntry(schedule.id, oldEntry.id);
            }
            for (final data in entries) {
               await repo.addEntry(schedule.id, data);
            }
            
            if (!mounted) return;
            _loadSchedule();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تمت تحديث الجدول بنجاح'),
                backgroundColor: AppColors.success,
              ),
            );
          } catch (_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('فشل تحديث الجدول'),
                backgroundColor: AppColors.coral,
              ),
            );
            rethrow;
          }
        },
      ),
    );
  }

  Widget _buildEntryTile(ScheduleEntryModel entry, Color dayColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(10),
        border: Border(right: BorderSide(color: dayColor, width: 3)),
      ),
      child: Row(
        children: [
          // Time
          Column(
            children: [
              Text(
                entry.startTime,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
              ),
              Container(width: 1, height: 12, color: AppColors.darkCardElevated),
              Text(
                entry.endTime,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // Title + Teacher
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary),
                ),
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
            decoration: BoxDecoration(
              color: AppColors.darkCardElevated,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              entry.recurrenceDisplay,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTile(ClassSessionModel session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  '${session.sessionDate.day}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.primary),
                ),
                Text(
                  session.effectiveDateDisplay,
                  style: const TextStyle(fontSize: 12, color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${session.startTime12h} - ${session.endTime12h}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    if (session.teacherName != null) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.person_outline, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        session.teacherName!,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.darkCardElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              session.statusDisplay,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

}
