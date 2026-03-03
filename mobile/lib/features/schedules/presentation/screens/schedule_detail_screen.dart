import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/schedule_model.dart';

class ScheduleDetailScreen extends StatefulWidget {
  final int scheduleId;
  const ScheduleDetailScreen({super.key, required this.scheduleId});

  @override
  State<ScheduleDetailScreen> createState() => _ScheduleDetailScreenState();
}

class _ScheduleDetailScreenState extends State<ScheduleDetailScreen> {
  ScheduleModel? _schedule;

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

  void _loadSchedule() {
    if (AuthBloc.demoMode) {
      final mocks = _demoSchedules();
      final found = mocks.where((s) => s.id == widget.scheduleId);
      if (found.isNotEmpty) setState(() => _schedule = found.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_schedule == null) {
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
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () {}),
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
        ],
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

  List<ScheduleModel> _demoSchedules() {
    final now = DateTime.now();
    return [
      ScheduleModel(id: 1, name: 'جدول الفصل الدراسي الأول', description: 'الجدول الأساسي للفصل الدراسي الأول 1446هـ', startDate: DateTime(now.year, 9, 1), endDate: DateTime(now.year, 12, 30), isActive: true, entries: [
        ScheduleEntryModel(id: 1, scheduleId: 1, teacherName: 'أ. عبدالله المحمد', title: 'القرآن الكريم', dayOfWeek: 0, startTime: '08:00', endTime: '09:00', recurrence: 'weekly'),
        ScheduleEntryModel(id: 2, scheduleId: 1, teacherName: 'أ. فاطمة الأحمد', title: 'الرياضيات', dayOfWeek: 0, startTime: '09:30', endTime: '10:30', recurrence: 'weekly'),
        ScheduleEntryModel(id: 3, scheduleId: 1, teacherName: 'أ. خالد العتيبي', title: 'اللغة العربية', dayOfWeek: 1, startTime: '08:00', endTime: '09:00', recurrence: 'weekly'),
        ScheduleEntryModel(id: 4, scheduleId: 1, teacherName: 'أ. نورة السعيد', title: 'العلوم', dayOfWeek: 2, startTime: '10:00', endTime: '11:00', recurrence: 'weekly'),
        ScheduleEntryModel(id: 5, scheduleId: 1, teacherName: 'أ. عبدالله المحمد', title: 'التجويد', dayOfWeek: 3, startTime: '08:00', endTime: '09:00', recurrence: 'weekly'),
      ]),
      ScheduleModel(id: 2, name: 'جدول حلقة التحفيظ المسائية', description: 'حلقة التحفيظ المسائية للطلاب المتفوقين', startDate: DateTime(now.year, 9, 15), endDate: DateTime(now.year + 1, 1, 15), isActive: true, entries: [
        ScheduleEntryModel(id: 6, scheduleId: 2, teacherName: 'أ. عبدالله المحمد', title: 'حفظ القرآن', dayOfWeek: 0, startTime: '16:00', endTime: '17:30', recurrence: 'weekly'),
        ScheduleEntryModel(id: 7, scheduleId: 2, teacherName: 'أ. عبدالله المحمد', title: 'مراجعة الحفظ', dayOfWeek: 2, startTime: '16:00', endTime: '17:30', recurrence: 'weekly'),
        ScheduleEntryModel(id: 8, scheduleId: 2, teacherName: 'أ. عبدالله المحمد', title: 'تسميع الحفظ', dayOfWeek: 4, startTime: '16:00', endTime: '17:30', recurrence: 'weekly'),
      ]),
      ScheduleModel(id: 3, name: 'الدورة الصيفية المكثفة', description: 'دورة صيفية مكثفة لتأسيس الطلاب', startDate: DateTime(now.year, 6, 1), endDate: DateTime(now.year, 8, 31), isActive: false, entries: [
        ScheduleEntryModel(id: 9, scheduleId: 3, teacherName: 'أ. خالد العتيبي', title: 'نحو وصرف', dayOfWeek: 0, startTime: '09:00', endTime: '11:00', recurrence: 'weekly'),
        ScheduleEntryModel(id: 10, scheduleId: 3, teacherName: 'أ. خالد العتيبي', title: 'إملاء وتعبير', dayOfWeek: 2, startTime: '09:00', endTime: '11:00', recurrence: 'weekly'),
      ]),
      ScheduleModel(id: 4, name: 'برنامج التقوية في الرياضيات', description: 'برنامج أسبوعي لتقوية الطلاب الضعاف', startDate: DateTime(now.year, 10, 1), endDate: DateTime(now.year, 12, 15), isActive: true, entries: [
        ScheduleEntryModel(id: 11, scheduleId: 4, teacherName: 'أ. فاطمة الأحمد', title: 'تقوية رياضيات', dayOfWeek: 1, startTime: '14:00', endTime: '15:30', recurrence: 'weekly'),
        ScheduleEntryModel(id: 12, scheduleId: 4, teacherName: 'أ. فاطمة الأحمد', title: 'تمارين تطبيقية', dayOfWeek: 3, startTime: '14:00', endTime: '15:30', recurrence: 'biweekly'),
      ]),
    ];
  }
}
