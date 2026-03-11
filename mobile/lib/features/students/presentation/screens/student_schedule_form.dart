import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class StudentScheduleForm extends StatefulWidget {
  final String? studentName;
  final void Function(String scheduleName, List<Map<String, dynamic>> entries) onSave;

  const StudentScheduleForm({super.key, this.studentName, required this.onSave});

  @override
  State<StudentScheduleForm> createState() => _StudentScheduleFormState();
}

class _StudentScheduleFormState extends State<StudentScheduleForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  // Multi-day selection
  final Set<int> _selectedDays = {};
  bool _sameTimeForAll = true;

  // Shared time (when _sameTimeForAll = true)
  TimeOfDay _sharedStartTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _sharedEndTime = const TimeOfDay(hour: 9, minute: 0);

  // Per-day times (when _sameTimeForAll = false)
  final Map<int, TimeOfDay> _perDayStart = {};
  final Map<int, TimeOfDay> _perDayEnd = {};

  String? _selectedTeacher;
  String _recurrence = 'weekly';

  static const _days = [
    'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت',
  ];

  static const _teachers = [
    'أ. عبدالله المحمد',
    'أ. فاطمة الأحمد',
    'أ. خالد العتيبي',
    'أ. نورة السعيد',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart, {int? dayIndex}) async {
    TimeOfDay initial;
    if (dayIndex != null) {
      initial = isStart
          ? (_perDayStart[dayIndex] ?? const TimeOfDay(hour: 8, minute: 0))
          : (_perDayEnd[dayIndex] ?? const TimeOfDay(hour: 9, minute: 0));
    } else {
      initial = isStart ? _sharedStartTime : _sharedEndTime;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.darkCard,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        if (dayIndex != null) {
          if (isStart) {
            _perDayStart[dayIndex] = picked;
          } else {
            _perDayEnd[dayIndex] = picked;
          }
        } else {
          if (isStart) {
            _sharedStartTime = picked;
          } else {
            _sharedEndTime = picked;
          }
        }
      });
    }
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر يوم واحد على الأقل'), backgroundColor: AppColors.coral),
      );
      return;
    }

    final entries = <Map<String, dynamic>>[];
    for (final day in _selectedDays.toList()..sort()) {
      final startTime = _sameTimeForAll
          ? _sharedStartTime
          : (_perDayStart[day] ?? const TimeOfDay(hour: 8, minute: 0));
      final endTime = _sameTimeForAll
          ? _sharedEndTime
          : (_perDayEnd[day] ?? const TimeOfDay(hour: 9, minute: 0));

      entries.add({
        'title': _titleController.text.trim(),
        'day_of_week': day,
        'start_time': _formatTime(startTime),
        'end_time': _formatTime(endTime),
        'teacher_name': _selectedTeacher,
        'recurrence': _recurrence,
      });
    }

    final fallbackName = widget.studentName != null ? 'جدول ${widget.studentName}' : 'جدول جديد';
    widget.onSave(fallbackName, entries);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Row(
                children: [
                  Icon(Icons.calendar_month, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('إضافة حصة جديدة / جدول', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 20),

              // Subject
              const Text('المادة / العنوان (للحصص)', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'مثال: القرآن الكريم',
                  filled: true,
                  fillColor: AppColors.darkCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: 16),

              // Multi-Day Selection
              const Text('الأيام (اختر أكثر من يوم)', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: List.generate(_days.length, (i) {
                  final selected = _selectedDays.contains(i);
                  return FilterChip(
                    label: Text(_days[i]),
                    selected: selected,
                    selectedColor: AppColors.primary,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedDays.add(i);
                        } else {
                          _selectedDays.remove(i);
                        }
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),

              // Same time toggle
              if (_selectedDays.length > 1) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.darkCard,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Switch(
                        value: _sameTimeForAll,
                        activeTrackColor: AppColors.primary,
                        onChanged: (v) => setState(() => _sameTimeForAll = v),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _sameTimeForAll ? 'نفس الوقت لكل الأيام' : 'وقت مختلف لكل يوم',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Time Pickers
              if (_sameTimeForAll || _selectedDays.length <= 1)
                _buildTimePickers()
              else
                ...(_selectedDays.toList()..sort())
                    .map((day) => _buildTimePickers(dayIndex: day)),

              const SizedBox(height: 16),

              // Teacher Dropdown (Searchable)
              const Text('المعلم (اختياري)', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownMenu<String>(
                width: MediaQuery.of(context).size.width - 48,
                initialSelection: _selectedTeacher,
                hintText: 'ابحث واختر المعلم',
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: AppColors.darkCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                dropdownMenuEntries: _teachers.map((t) => DropdownMenuEntry(value: t, label: t)).toList(),
                onSelected: (v) => setState(() => _selectedTeacher = v),
              ),
              const SizedBox(height: 16),

              // Recurrence
              const Text('تكرار الحصة', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _recurrence,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.darkCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                dropdownColor: AppColors.darkCard,
                items: const [
                  DropdownMenuItem(value: 'weekly', child: Text('أسبوعياً')),
                  DropdownMenuItem(value: 'biweekly', child: Text('كل أسبوعين')),
                  DropdownMenuItem(value: 'once', child: Text('مرة واحدة')),
                ],
                onChanged: (v) => setState(() => _recurrence = v!),
              ),
              const SizedBox(height: 24),

              // Save
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _selectedDays.length > 1 ? 'حفظ ${_selectedDays.length} حصص' : 'حفظ الحصة',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimePickers({int? dayIndex}) {
    final start = dayIndex != null
        ? (_perDayStart[dayIndex] ?? const TimeOfDay(hour: 8, minute: 0))
        : _sharedStartTime;
    final end = dayIndex != null
        ? (_perDayEnd[dayIndex] ?? const TimeOfDay(hour: 9, minute: 0))
        : _sharedEndTime;

    return Padding(
      padding: EdgeInsets.only(bottom: dayIndex != null ? 12 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dayIndex != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(_days[dayIndex], style: TextStyle(fontWeight: FontWeight.w700, color: _dayColor(dayIndex), fontSize: 13)),
            ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('من', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _pickTime(true, dayIndex: dayIndex),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(10)),
                        child: Row(children: [
                          const Icon(Icons.access_time, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(_formatTime(start), style: const TextStyle(fontWeight: FontWeight.w600)),
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
                    const Text('إلى', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _pickTime(false, dayIndex: dayIndex),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(10)),
                        child: Row(children: [
                          const Icon(Icons.access_time, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(_formatTime(end), style: const TextStyle(fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _dayColor(int day) {
    const colors = [
      Color(0xFF26A69A), Color(0xFF42A5F5), Color(0xFFAB47BC), Color(0xFFEF5350),
      Color(0xFFFF7043), Color(0xFF66BB6A), Color(0xFFFFA726),
    ];
    return (day >= 0 && day < colors.length) ? colors[day] : AppColors.primary;
  }
}
