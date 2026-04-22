import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../../data/models/calendar_teacher_timetable_model.dart';
import '../../data/models/calendar_event_model.dart';
import 'teacher_students_page.dart';

class TeacherTimetablePage extends StatefulWidget {
  final int teacherId;
  final String teacherName;

  const TeacherTimetablePage({
    super.key,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  State<TeacherTimetablePage> createState() => _TeacherTimetablePageState();
}

class _TeacherTimetablePageState extends State<TeacherTimetablePage> {
  final _formKey = GlobalKey<FormState>();
  final _studentNameController = TextEditingController();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _selectedCountry;
  List<String> _selectedDays = [];
  bool _isSubmitting = false;
  bool _isFormExpanded = false; // Form collapsed by default

  final List<String> _days = [
    'Saturday',
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];

  final List<String> _countries = ['canada', 'uk', 'eg'];

  @override
  void dispose() {
    _studentNameController.dispose();
    super.dispose();
  }

  String _convertTo24Hour(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _getArabicDayName(String englishDay) {
    const dayNames = {
      'Sunday': 'الأحد',
      'Monday': 'الاثنين',
      'Tuesday': 'الثلاثاء',
      'Wednesday': 'الأربعاء',
      'Thursday': 'الخميس',
      'Friday': 'الجمعة',
      'Saturday': 'السبت',
    };
    return dayNames[englishDay] ?? englishDay;
  }

  void _submitForm() {
    if (_formKey.currentState!.validate() &&
        _startTime != null &&
        _endTime != null &&
        _selectedDays.isNotEmpty &&
        _selectedCountry != null) {
      setState(() {
        _isSubmitting = true;
      });

      // Create timetable entries for each selected day
      for (final day in _selectedDays) {
        final timetable = CalendarTeacherTimetableModel(
          id: 0,
          teacherId: widget.teacherId,
          day: day,
          startTime: _convertTo24Hour(_startTime!),
          finishTime: _convertTo24Hour(_endTime!),
          studentName: _studentNameController.text,
          country: _selectedCountry!,
          status: 'active',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        context.read<CalendarBloc>().add(CreateTeacherTimetable(timetable));
      }

      // Reset form
      _studentNameController.clear();
      setState(() {
        _startTime = null;
        _endTime = null;
        _selectedDays = [];
        _selectedCountry = null;
        _isSubmitting = false;
      });
    }
  }

  void _showDeleteConfirmation(CalendarTeacherTimetableModel timetable) {
    // Capture the bloc before showing the dialog
    final bloc = context.read<CalendarBloc>();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف حصة ${timetable.studentName}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              bloc.add(
                    DeleteTeacherTimetable(timetable.id),
                  );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  List<CalendarTeacherTimetableModel> _getTimetablesForDay(
    List<CalendarTeacherTimetableModel> timetables,
    String day,
    String time,
  ) {
    return timetables.where((t) {
      // Match by day and time (HH:MM format)
      final tTime = t.startTime.split(':').take(2).join(':');
      return t.day == day && tTime == time;
    }).toList();
  }

  String _formatTime(String time) {
    try {
      final parts = time.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = parts[1];
        if (hour == 0) {
          return '12:$minute AM';
        } else if (hour < 12) {
          return '$hour:$minute AM';
        } else if (hour == 12) {
          return '12:$minute PM';
        } else {
          return '${hour - 12}:$minute PM';
        }
      }
      return time;
    } catch (e) {
      return time;
    }
  }

  @override
  void initState() {
    super.initState();
    // Load timetables for this teacher
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CalendarBloc>().add(LoadCalendarEvents(teacherId: widget.teacherId));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('جداول ${widget.teacherName}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_rounded),
            tooltip: 'الطلاب',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => BlocProvider.value(
                    value: context.read<CalendarBloc>(),
                    child: TeacherStudentsPage(
                      teacherId: widget.teacherId,
                      teacherName: widget.teacherName,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<CalendarBloc, CalendarState>(
        listener: (context, state) {
          if (state is CalendarOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تمت العملية بنجاح'),
                backgroundColor: Colors.green,
              ),
            );
            // Reload timetables
            context.read<CalendarBloc>().add(LoadCalendarEvents(teacherId: widget.teacherId));
            setState(() {
              _isSubmitting = false;
            });
          } else if (state is CalendarError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
            setState(() {
              _isSubmitting = false;
            });
          }
        },
        builder: (context, state) {
          if (state is CalendarLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Get timetables for this teacher from events
          List<CalendarTeacherTimetableModel> timetables = [];
          List<CalendarEventModel> exceptionalClasses = [];
          if (state is CalendarEventsLoaded) {
            final teacherEvents = state.events.where((event) => event.teacherId == widget.teacherId);
            
            // Separate recurring timetables and exceptional classes
            timetables = teacherEvents
                .where((event) => !event.isExceptional)
                .map((event) {
              return CalendarTeacherTimetableModel(
                id: event.id,
                teacherId: widget.teacherId,
                day: event.day,
                startTime: event.startTime,
                finishTime: event.endTime,
                studentName: event.studentName,
                country: event.country,
                status: 'active',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
            }).toList();
            
            // Get exceptional classes
            exceptionalClasses = teacherEvents
                .where((event) => event.isExceptional)
                .toList();
          }

          // Get unique start times and sort them
          final uniqueStartTimes = timetables
              .map((t) {
                final parts = t.startTime.split(':');
                if (parts.length >= 2) {
                  return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
                }
                return t.startTime;
              })
              .toSet()
              .toList();
          
          // Sort times properly (HH:MM format)
          uniqueStartTimes.sort((a, b) {
            final aParts = a.split(':');
            final bParts = b.split(':');
            if (aParts.length >= 2 && bParts.length >= 2) {
              final aHour = int.tryParse(aParts[0]) ?? 0;
              final aMin = int.tryParse(aParts[1]) ?? 0;
              final bHour = int.tryParse(bParts[0]) ?? 0;
              final bMin = int.tryParse(bParts[1]) ?? 0;
              if (aHour != bHour) {
                return aHour.compareTo(bHour);
              }
              return aMin.compareTo(bMin);
            }
            return a.compareTo(b);
          });

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Add Timetable Form (Collapsible)
                Card(
                  child: ExpansionTile(
                    initiallyExpanded: _isFormExpanded,
                    onExpansionChanged: (expanded) {
                      setState(() {
                        _isFormExpanded = expanded;
                      });
                    },
                    title: const Text(
                      'إضافة حصة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    leading: Icon(
                      _isFormExpanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.primary,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppSizes.spaceLg),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _studentNameController,
                                decoration: const InputDecoration(
                                  labelText: 'اسم الطالب',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'يرجى إدخال اسم الطالب';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSizes.spaceMd),
                              // Start Time
                              InkWell(
                                onTap: () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: _startTime ?? TimeOfDay.now(),
                                    builder: (context, child) {
                                      return MediaQuery(
                                        data: MediaQuery.of(context).copyWith(
                                          alwaysUse24HourFormat: false,
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (time != null) {
                                    setState(() {
                                      _startTime = time;
                                    });
                                  }
                                },
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'وقت البداية',
                                    border: const OutlineInputBorder(),
                                    suffixIcon: const Icon(Icons.access_time),
                                  ),
                                  child: Text(
                                    _startTime != null
                                        ? _formatTimeOfDay(_startTime!)
                                        : 'اختر وقت البداية',
                                    style: TextStyle(
                                      color: _startTime != null
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSizes.spaceMd),
                              // End Time
                              InkWell(
                                onTap: () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: _endTime ?? TimeOfDay.now(),
                                    builder: (context, child) {
                                      return MediaQuery(
                                        data: MediaQuery.of(context).copyWith(
                                          alwaysUse24HourFormat: false,
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (time != null) {
                                    setState(() {
                                      _endTime = time;
                                    });
                                  }
                                },
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'وقت النهاية',
                                    border: const OutlineInputBorder(),
                                    suffixIcon: const Icon(Icons.access_time),
                                  ),
                                  child: Text(
                                    _endTime != null
                                        ? _formatTimeOfDay(_endTime!)
                                        : 'اختر وقت النهاية',
                                    style: TextStyle(
                                      color: _endTime != null
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSizes.spaceMd),
                              // Country
                              DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'البلد',
                                  border: OutlineInputBorder(),
                                ),
                                value: _selectedCountry,
                                items: _countries.map((country) {
                                  String label;
                                  switch (country) {
                                    case 'canada':
                                      label = 'كندا';
                                      break;
                                    case 'uk':
                                      label = 'المملكة المتحدة';
                                      break;
                                    case 'eg':
                                      label = 'مصر';
                                      break;
                                    default:
                                      label = country;
                                  }
                                  return DropdownMenuItem(
                                    value: country,
                                    child: Text(label),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedCountry = value;
                                  });
                                },
                                validator: (value) {
                                  if (value == null) {
                                    return 'يرجى اختيار البلد';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSizes.spaceMd),
                              // Days (Multi-select)
                              const Text('الأيام:'),
                              Wrap(
                                spacing: AppSizes.spaceSm,
                                children: _days.map((day) {
                                  final isSelected = _selectedDays.contains(day);
                                  return FilterChip(
                                    label: Text(_getArabicDayName(day)),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedDays.add(day);
                                        } else {
                                          _selectedDays.remove(day);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: AppSizes.spaceLg),
                              ElevatedButton(
                                onPressed: _isSubmitting ? null : _submitForm,
                                child: _isSubmitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('إضافة'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSizes.spaceLg),

                // Exceptional Classes Section
                if (exceptionalClasses.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.spaceLg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.star_rounded, color: Colors.orange, size: 24),
                              const SizedBox(width: AppSizes.spaceSm),
                              const Text(
                                'الحصص الاستثنائية',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSizes.spaceMd),
                          ...exceptionalClasses.map((event) {
                            final exceptionalDate = event.exceptionalDate;
                            final date = exceptionalDate != null
                                ? DateTime.tryParse(exceptionalDate)
                                : null;
                            return Container(
                              margin: const EdgeInsets.only(bottom: AppSizes.spaceSm),
                              padding: const EdgeInsets.all(AppSizes.spaceMd),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.orange,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.star_rounded, color: Colors.orange, size: 20),
                                  const SizedBox(width: AppSizes.spaceSm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          event.studentName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                                            const SizedBox(width: 4),
                                            Text(
                                              date != null
                                                  ? '${date.day}/${date.month}/${date.year}'
                                                  : exceptionalDate ?? '',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(width: AppSizes.spaceMd),
                                            Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                                            const SizedBox(width: 4),
                                            Text(
                                              _formatTime(event.startTime),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.spaceLg),
                ],

                // Timetable Grid
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.spaceLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'الجداول',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSizes.spaceMd),
                        // Table
                        SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                            headingRowColor: MaterialStateProperty.all(AppColors.primary),
                            headingTextStyle: const TextStyle(color: Colors.white),
                            columnSpacing: 8,
                            dataRowMinHeight: 50,
                            dataRowMaxHeight: 150,
                            columns: [
                              const DataColumn(label: Text('الوقت')),
                              ..._days.map((day) => DataColumn(
                                    label: Text(_getArabicDayName(day)),
                                  )),
                            ],
                            rows: uniqueStartTimes.map((time) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(_formatTime('$time:00'))),
                                  ..._days.map((day) {
                                    final dayTimetables = _getTimetablesForDay(
                                      timetables,
                                      day,
                                      time,
                                    );
                                    return DataCell(
                                      dayTimetables.isEmpty
                                          ? const SizedBox.shrink()
                                          : ClipRect(
                                              child: SizedBox(
                                                width: double.infinity,
                                                child: ConstrainedBox(
                                                  constraints: const BoxConstraints(
                                                    maxHeight: 150,
                                                  ),
                                                  child: SingleChildScrollView(
                                                    physics: const ClampingScrollPhysics(),
                                                    child: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: dayTimetables.map((timetable) {
                                                        final startTimeFormatted = _formatTime(timetable.startTime);
                                                        final endTimeFormatted = timetable.finishTime != null 
                                                            ? _formatTime(timetable.finishTime!) 
                                                            : '';
                                                        final timeRange = endTimeFormatted.isNotEmpty 
                                                            ? '$startTimeFormatted - $endTimeFormatted'
                                                            : startTimeFormatted;
                                                        
                                                        final isExceptional = timetable.id.toString().startsWith('exceptional_');
                                                        return Container(
                                                          margin: const EdgeInsets.only(bottom: 2),
                                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: isExceptional
                                                                ? Colors.orange.withOpacity(0.2)
                                                                : AppColors.primary.withOpacity(0.1),
                                                            borderRadius: BorderRadius.circular(4),
                                                            border: isExceptional
                                                                ? Border.all(color: Colors.orange, width: 1.5)
                                                                : null,
                                                          ),
                                                          child: Column(
                                                            mainAxisSize: MainAxisSize.min,
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  if (isExceptional)
                                                                    const Icon(
                                                                      Icons.star_rounded,
                                                                      size: 12,
                                                                      color: Colors.orange,
                                                                    ),
                                                                  Flexible(
                                                                    child: Text(
                                                                      timetable.studentName,
                                                                      style: TextStyle(
                                                                        fontSize: 12,
                                                                        fontWeight: FontWeight.bold,
                                                                        color: isExceptional ? Colors.orange.shade900 : null,
                                                                      ),
                                                                      maxLines: 1,
                                                                      overflow: TextOverflow.ellipsis,
                                                                    ),
                                                                  ),
                                                                  GestureDetector(
                                                                    onTap: () => _showDeleteConfirmation(timetable),
                                                                    child: const Padding(
                                                                      padding: EdgeInsets.all(6),
                                                                      child: Icon(
                                                                        Icons.delete_rounded,
                                                                        size: 18,
                                                                        color: Colors.red,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              Text(
                                                                timeRange,
                                                                style: const TextStyle(
                                                                  fontSize: 11,
                                                                  color: AppColors.textSecondary,
                                                                ),
                                                              ),
                                                              Text(
                                                                '${_getArabicDayName(timetable.day)} - ${timetable.country == 'canada' ? 'كندا' : timetable.country == 'eg' ? 'مصر' : 'المملكة المتحدة'}',
                                                                style: const TextStyle(
                                                                  fontSize: 10,
                                                                  color: AppColors.textSecondary,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      }).toList(),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                    );
                                  }),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
