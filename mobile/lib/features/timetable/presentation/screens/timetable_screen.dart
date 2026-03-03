import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../schedules/data/models/schedule_model.dart';
import '../../../students/presentation/screens/student_schedule_form.dart';

/// Shows ALL timetable entries grouped by student.
/// Includes search + add timetable for specific student.
class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  late List<_TimetableRow> _entries;
  String _searchQuery = '';

  // Demo student list for the add dropdown
  static const _allStudents = [
    _StudentOption(1, 'أحمد محمد الأنصاري'),
    _StudentOption(2, 'فاطمة علي السعدي'),
    _StudentOption(3, 'محمد خالد العتيبي'),
    _StudentOption(4, 'سارة أحمد النعيمي'),
    _StudentOption(5, 'عبدالله سعيد المهري'),
    _StudentOption(6, 'مريم يوسف الكبيسي'),
  ];

  @override
  void initState() {
    super.initState();
    _entries = AuthBloc.demoMode ? _demoEntries() : [];
  }

  static const _dayNames = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
  static const _dayColors = [
    Color(0xFF26A69A), Color(0xFF42A5F5), Color(0xFFAB47BC), Color(0xFFEF5350),
    Color(0xFFFF7043), Color(0xFF66BB6A), Color(0xFFFFA726),
  ];

  List<_TimetableRow> get _filteredEntries {
    if (_searchQuery.isEmpty) return _entries;
    final q = _searchQuery.toLowerCase();
    return _entries.where((e) =>
        e.studentName.toLowerCase().contains(q) ||
        e.entry.title.toLowerCase().contains(q) ||
        (e.entry.teacherName?.toLowerCase().contains(q) ?? false)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEntries;

    // Group by student
    final byStudent = <int, List<_TimetableRow>>{};
    final studentNames = <int, String>{};
    for (final e in filtered) {
      byStudent.putIfAbsent(e.studentId, () => []).add(e);
      studentNames[e.studentId] = e.studentName;
    }
    final studentIds = byStudent.keys.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('الجداول الزمنية'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_timetable',
        onPressed: _showAddTimetable,
        icon: const Icon(Icons.add),
        label: const Text('إضافة جدول'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'بحث عن طالب أو مادة...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _searchQuery = ''))
                    : null,
                filled: true,
                fillColor: AppColors.darkCard,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),

          // Content
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty ? Icons.search_off : Icons.calendar_month,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty ? 'لا توجد نتائج لـ "$_searchQuery"' : 'لا يوجد حصص مسجلة',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    children: [
                      // Summary bar
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.primary.withValues(alpha: 0.05)],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month, color: AppColors.primary, size: 24),
                            const SizedBox(width: 10),
                            Text('${studentIds.length} طالب', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary)),
                            const SizedBox(width: 6),
                            Text('• ${filtered.length} حصة', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Student sections
                      ...studentIds.map((sid) => _buildStudentSection(sid, byStudent[sid]!, studentNames[sid]!)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentSection(int sid, List<_TimetableRow> rows, String name) {
    rows.sort((a, b) {
      final d = a.entry.dayOfWeek.compareTo(b.entry.dayOfWeek);
      return d != 0 ? d : a.entry.startTime.compareTo(b.entry.startTime);
    });

    final byDay = <int, List<_TimetableRow>>{};
    for (final r in rows) {
      byDay.putIfAbsent(r.entry.dayOfWeek, () => []).add(r);
    }
    final sortedDays = byDay.keys.toList()..sort();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student header
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            onTap: () => context.push('/students/$sid'),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text('${rows.length} حصة • ${sortedDays.length} أيام', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left, color: AppColors.textSecondary, size: 20),
                ],
              ),
            ),
          ),
          Container(height: 1, color: AppColors.darkCardElevated),

          // Entries by day
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sortedDays.map((day) {
                final dayRows = byDay[day]!;
                final dayName = (day >= 0 && day < _dayNames.length) ? _dayNames[day] : '';
                final dayColor = (day >= 0 && day < _dayColors.length) ? _dayColors[day] : AppColors.primary;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: dayColor, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text(dayName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: dayColor)),
                          const SizedBox(width: 6),
                          Expanded(child: Container(height: 1, color: dayColor.withValues(alpha: 0.12))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...dayRows.map((row) => _buildEntryRow(row, dayColor)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryRow(_TimetableRow row, Color dayColor) {
    return InkWell(
      onTap: () => _openDetail(row),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 85,
              child: Text('${row.entry.startTime} - ${row.entry.endTime}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            ),
            Expanded(child: Text(row.entry.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
            if (row.entry.teacherName != null)
              Text(row.entry.teacherName!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: dayColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(row.entry.recurrenceDisplay, style: TextStyle(color: dayColor, fontSize: 9, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(_TimetableRow row) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TimetableDetailSheet(
        row: row,
        onDelete: () {
          setState(() => _entries.remove(row));
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم حذف "${row.entry.title}" لـ ${row.studentName}'), backgroundColor: AppColors.coral),
          );
        },
      ),
    );
  }

  // ── Add Timetable for a specific student ──
  void _showAddTimetable() {
    int? selectedStudentId;
    String? selectedStudentName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.person_add_alt_1, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('إضافة جدول لطالب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 16),

              // Searchable student dropdown
              const Text('اختر الطالب', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 6),
              Autocomplete<_StudentOption>(
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) return _allStudents;
                  final q = textEditingValue.text.toLowerCase();
                  return _allStudents.where((s) => s.name.toLowerCase().contains(q));
                },
                displayStringForOption: (s) => s.name,
                fieldViewBuilder: (ctx, controller, focusNode, onFieldSubmitted) => TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن طالب...',
                    prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.darkCard,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                optionsViewBuilder: (ctx, onSelected, options) => Align(
                  alignment: Alignment.topRight,
                  child: Material(
                    color: AppColors.darkCard,
                    elevation: 4,
                    borderRadius: BorderRadius.circular(10),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (_, i) {
                          final opt = options.elementAt(i);
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                              child: Text(opt.name[0], style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                            title: Text(opt.name, style: const TextStyle(fontSize: 14)),
                            onTap: () {
                              onSelected(opt);
                              setSheetState(() {
                                selectedStudentId = opt.id;
                                selectedStudentName = opt.name;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
                onSelected: (s) => setSheetState(() {
                  selectedStudentId = s.id;
                  selectedStudentName = s.name;
                }),
              ),
              const SizedBox(height: 16),

              if (selectedStudentId != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('تم اختيار: $selectedStudentName', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Next button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: selectedStudentId == null
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          _openScheduleFormForStudent(selectedStudentId!, selectedStudentName!);
                        },
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('التالي: إضافة الحصص'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openScheduleFormForStudent(int studentId, String studentName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StudentScheduleForm(
        onSave: (entries) {
          setState(() {
            for (final data in entries) {
              _entries.add(_TimetableRow(
                studentName,
                studentId,
                ScheduleEntryModel(
                  id: DateTime.now().millisecondsSinceEpoch + (data['day_of_week'] as int),
                  scheduleId: null,
                  teacherName: data['teacher_name'] as String?,
                  title: data['title'] as String,
                  dayOfWeek: data['day_of_week'] as int,
                  startTime: data['start_time'] as String,
                  endTime: data['end_time'] as String,
                  recurrence: 'weekly',
                ),
              ));
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم إضافة ${entries.length} حصة لـ $studentName'),
              backgroundColor: AppColors.success,
            ),
          );
        },
      ),
    );
  }

  List<_TimetableRow> _demoEntries() {
    return [
      _TimetableRow('أحمد محمد الأنصاري', 1, ScheduleEntryModel(id: 1, scheduleId: null, teacherName: 'أ. عبدالله المحمد', title: 'القرآن الكريم', dayOfWeek: 0, startTime: '08:00', endTime: '09:00', recurrence: 'weekly')),
      _TimetableRow('أحمد محمد الأنصاري', 1, ScheduleEntryModel(id: 2, scheduleId: null, teacherName: 'أ. فاطمة الأحمد', title: 'الرياضيات', dayOfWeek: 0, startTime: '09:30', endTime: '10:30', recurrence: 'weekly')),
      _TimetableRow('أحمد محمد الأنصاري', 1, ScheduleEntryModel(id: 3, scheduleId: null, teacherName: 'أ. خالد العتيبي', title: 'اللغة العربية', dayOfWeek: 1, startTime: '08:00', endTime: '09:00', recurrence: 'weekly')),
      _TimetableRow('أحمد محمد الأنصاري', 1, ScheduleEntryModel(id: 4, scheduleId: null, teacherName: 'أ. نورة السعيد', title: 'العلوم', dayOfWeek: 2, startTime: '10:00', endTime: '11:00', recurrence: 'weekly')),
      _TimetableRow('فاطمة علي السعدي', 2, ScheduleEntryModel(id: 5, scheduleId: null, teacherName: 'أ. عبدالله المحمد', title: 'القرآن الكريم', dayOfWeek: 0, startTime: '10:00', endTime: '11:00', recurrence: 'weekly')),
      _TimetableRow('فاطمة علي السعدي', 2, ScheduleEntryModel(id: 6, scheduleId: null, teacherName: 'أ. فاطمة الأحمد', title: 'الرياضيات', dayOfWeek: 1, startTime: '09:00', endTime: '10:00', recurrence: 'weekly')),
      _TimetableRow('فاطمة علي السعدي', 2, ScheduleEntryModel(id: 7, scheduleId: null, teacherName: 'أ. خالد العتيبي', title: 'اللغة الإنجليزية', dayOfWeek: 3, startTime: '08:00', endTime: '09:00', recurrence: 'weekly')),
      _TimetableRow('محمد خالد العتيبي', 3, ScheduleEntryModel(id: 8, scheduleId: null, teacherName: 'أ. نورة السعيد', title: 'الفيزياء', dayOfWeek: 0, startTime: '11:00', endTime: '12:00', recurrence: 'weekly')),
      _TimetableRow('محمد خالد العتيبي', 3, ScheduleEntryModel(id: 9, scheduleId: null, teacherName: 'أ. عبدالله المحمد', title: 'الكيمياء', dayOfWeek: 4, startTime: '08:00', endTime: '09:30', recurrence: 'biweekly')),
    ];
  }
}

class _TimetableRow {
  final String studentName;
  final int studentId;
  final ScheduleEntryModel entry;

  const _TimetableRow(this.studentName, this.studentId, this.entry);
}

class _StudentOption {
  final int id;
  final String name;

  const _StudentOption(this.id, this.name);
}

/// Detail sheet with full entry info + controls
class _TimetableDetailSheet extends StatelessWidget {
  final _TimetableRow row;
  final VoidCallback onDelete;

  const _TimetableDetailSheet({required this.row, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final entry = row.entry;

    const dayNames = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    const dayColors = [
      Color(0xFF26A69A), Color(0xFF42A5F5), Color(0xFFAB47BC), Color(0xFFEF5350),
      Color(0xFFFF7043), Color(0xFF66BB6A), Color(0xFFFFA726),
    ];
    final dayColor = (entry.dayOfWeek >= 0 && entry.dayOfWeek < dayColors.length) ? dayColors[entry.dayOfWeek] : AppColors.primary;
    final dayName = (entry.dayOfWeek >= 0 && entry.dayOfWeek < dayNames.length) ? dayNames[entry.dayOfWeek] : '';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: dayColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.calendar_month, color: dayColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(dayName, style: TextStyle(color: dayColor, fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _infoRow(Icons.school_outlined, 'الطالب', row.studentName, AppColors.primary),
          _infoRow(Icons.access_time, 'الوقت', '${entry.startTime} — ${entry.endTime}', dayColor),
          if (entry.teacherName != null)
            _infoRow(Icons.person_outline, 'المعلم', entry.teacherName!, AppColors.textSecondary),
          _infoRow(Icons.repeat, 'التكرار', entry.recurrenceDisplay, AppColors.textSecondary),
          if (entry.notes != null && entry.notes!.isNotEmpty)
            _infoRow(Icons.note_outlined, 'ملاحظات', entry.notes!, AppColors.textSecondary),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/students/${row.studentId}');
                  },
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('فتح الطالب'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('حذف الحصة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.coral,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          SizedBox(width: 60, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
        ],
      ),
    );
  }
}
