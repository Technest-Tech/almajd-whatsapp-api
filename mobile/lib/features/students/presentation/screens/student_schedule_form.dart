import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../teachers/data/teacher_repository.dart';
import '../../../teachers/data/models/teacher_model.dart';
import '../../../schedules/data/models/schedule_model.dart';

class StudentScheduleForm extends StatefulWidget {
  final String? studentName;
  final ScheduleModel? existingSchedule;
  final Future<void> Function(String scheduleName, List<Map<String, dynamic>> entries) onSave;

  const StudentScheduleForm({
    super.key,
    this.studentName,
    this.existingSchedule,
    required this.onSave,
  });

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

  bool _isLoadingTeachers = true;
  bool _saving = false;
  List<TeacherModel> _teachers = [];
  TeacherModel? _selectedTeacher;
  final String _recurrence = 'weekly';

  static const _days = [
    'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت',
  ];

  @override
  void initState() {
    super.initState();
    _loadTeachersAndInit();
  }

  Future<void> _loadTeachersAndInit() async {
    try {
      final loadedTeachers = await getIt<TeacherRepository>().getTeachers(perPage: 100);
      if (mounted) {
        setState(() {
          _teachers = loadedTeachers;
          _isLoadingTeachers = false;
        });
        _initExistingSchedule();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTeachers = false);
      }
    }
  }

  void _initExistingSchedule() {
    final schedule = widget.existingSchedule;
    if (schedule != null) {
      _titleController.text = schedule.name;
      if (schedule.entries.isNotEmpty) {
        // Find most frequent teacher id
        final teacherIds = schedule.entries.map((e) => e.teacherId).where((id) => id != null).cast<int>().toList();
        if (teacherIds.isNotEmpty) {
           final teacherCounts = <int, int>{};
           for (final id in teacherIds) {
             teacherCounts[id] = (teacherCounts[id] ?? 0) + 1;
           }
           final mostFrequentId = teacherCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
           
           try {
             setState(() {
               _selectedTeacher = _teachers.firstWhere((t) => t.id == mostFrequentId);
             });
           } catch (_) {
             // If the teacher isn't in the loaded list for some reason, we could try a targeted fetch, 
             // but for now leave blank if not found in the first 100.
           }
        }

        // Add correct days
        setState(() {
          for (var entry in schedule.entries) {
            _selectedDays.add(entry.dayOfWeek);

            // Parse HH:mm
            if (entry.startTime.contains(':')) {
               final stParts = entry.startTime.split(':');
               _perDayStart[entry.dayOfWeek] = TimeOfDay(hour: int.parse(stParts[0]), minute: int.parse(stParts[1]));
            }
            if (entry.endTime.contains(':')) {
               final etParts = entry.endTime.split(':');
               _perDayEnd[entry.dayOfWeek] = TimeOfDay(hour: int.parse(etParts[0]), minute: int.parse(etParts[1]));
            }
          }

          // Check if all start/end times are identical across days to toggle `_sameTimeForAll`
          if (_selectedDays.length > 1) {
            final firstDay = _selectedDays.first;
            final firstStart = _perDayStart[firstDay];
            final firstEnd = _perDayEnd[firstDay];
            bool allMatch = true;
            for (var day in _selectedDays) {
              if (_perDayStart[day] != firstStart || _perDayEnd[day] != firstEnd) {
                allMatch = false;
                break;
              }
            }
            _sameTimeForAll = allMatch;
            if (allMatch && firstStart != null && firstEnd != null) {
               _sharedStartTime = firstStart;
               _sharedEndTime = firstEnd;
            }
          }
        });
      }
    }
  }

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

  String _formatTime24(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _formatTime12(TimeOfDay t) {
    var hour = t.hour;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = hour < 12 ? 'ص' : 'م';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    return '$hour:$minute $period';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر يوم واحد على الأقل'), backgroundColor: AppColors.coral),
      );
      return;
    }
    if (_selectedTeacher == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر معلماً للحصة', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.coral),
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
        'start_time': _formatTime24(startTime),
        'end_time': _formatTime24(endTime),
        'teacher_id': _selectedTeacher!.id,
        'teacher_name': _selectedTeacher!.name,
        'recurrence': _recurrence,
      });
    }

    final fallbackName = widget.existingSchedule != null
        ? widget.existingSchedule!.name
        : (widget.studentName != null ? 'جدول ${widget.studentName}' : 'جدول جديد');
        
    setState(() => _saving = true);
    try {
      await widget.onSave(
        _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : fallbackName, 
        entries
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      // Parents handle error logging and snackbars. We just catch to prevent unhandled bubblups.
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
              Row(
                children: [
                  const Icon(Icons.calendar_month, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(widget.existingSchedule != null ? 'تعديل الجدول' : 'إضافة جدول جديد', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
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

              // Teacher selection (searchable in a bottom sheet)
              const Text('المعلم', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 6),
              InkWell(
                onTap: _openTeacherPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.darkCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.darkCardElevated),
                  ),
                  child: Row(
                    children: [
                      if (_isLoadingTeachers) ...[
                         const SizedBox(
                           width: 18,
                           height: 18,
                           child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                         ),
                         const SizedBox(width: 8),
                         const Expanded(
                           child: Text('جارٍ تحميل المعلمين...', style: TextStyle(color: AppColors.textSecondary)),
                         ),
                      ] else ...[
                         const Icon(Icons.person_search_rounded, size: 18, color: AppColors.textSecondary),
                         const SizedBox(width: 8),
                         Expanded(
                           child: Text(
                             _selectedTeacher?.name ?? 'ابحث واختر المعلم',
                             style: TextStyle(
                               color: _selectedTeacher == null
                                   ? AppColors.textSecondary
                                   : AppColors.textPrimary,
                               fontWeight: _selectedTeacher == null ? FontWeight.normal : FontWeight.w600,
                             ),
                             overflow: TextOverflow.ellipsis,
                           ),
                         ),
                         const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Save
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving 
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        widget.existingSchedule != null ? 'حفظ التعديلات' : 'حفظ الجدول',
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
          Container(
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('من', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => _pickTime(true, dayIndex: dayIndex),
                        child: Row(children: [
                          const Icon(Icons.access_time, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(_formatTime12(start), style: const TextStyle(fontWeight: FontWeight.w600)),
                        ]),
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
                        child: Row(children: [
                          const Icon(Icons.access_time, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(_formatTime12(end), style: const TextStyle(fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

  void _openTeacherPicker() {
    if (_isLoadingTeachers) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String query = '';
        List<TeacherModel> filtered = List.of(_teachers);

        void applyFilter(String q) {
          query = q;
          filtered = _teachers
              .where((t) => t.name.toLowerCase().contains(query.toLowerCase()))
              .toList();
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            final height = MediaQuery.of(ctx).size.height * 0.6;

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: bottomInset + 20,
                ),
                child: SizedBox(
                  height: height,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.person_search_rounded, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text('اختر المعلم', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        autofocus: true,
                        onChanged: (v) => setModalState(() => applyFilter(v)),
                        decoration: InputDecoration(
                          hintText: 'ابحث بالاسم...',
                          prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                          filled: true,
                          fillColor: AppColors.darkBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('لا يوجد معلمون مطابقون', style: TextStyle(color: AppColors.textSecondary)),
                                ),
                              )
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (_, i) {
                                  final teacher = filtered[i];
                                  final selected = teacher.id == _selectedTeacher?.id;
                                  return ListTile(
                                    leading: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppColors.primary,
                                      child: Text(
                                        teacher.initials,
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    title: Text(teacher.name),
                                    trailing: selected
                                        ? const Icon(Icons.check, color: AppColors.primary)
                                        : null,
                                    onTap: () {
                                      setState(() {
                                        _selectedTeacher = teacher;
                                      });
                                      Navigator.of(context).pop();
                                    },
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
}
