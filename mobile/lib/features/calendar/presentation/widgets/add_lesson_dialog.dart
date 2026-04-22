import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../data/models/calendar_exceptional_class_model.dart';
import '../../data/models/calendar_teacher_timetable_model.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';

class AddLessonDialog extends StatefulWidget {
  const AddLessonDialog({Key? key}) : super(key: key);

  @override
  State<AddLessonDialog> createState() => _AddLessonDialogState();
}

class _AddLessonDialogState extends State<AddLessonDialog> {
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedStudent;
  int? _selectedTeacherId;
  String? _selectedTeacherName;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay.now().replacing(hour: TimeOfDay.now().hour + 1);
  String _lessonType = 'one_time'; // 'one_time' or 'permanent'
  String? _selectedDay;
  String _selectedCountry = 'canada';
  
  List<String> _students = [];
  List<Map<String, dynamic>> _teachers = [];
  bool _isLoadingStudents = true;
  bool _isLoadingTeachers = true;

  final List<String> _days = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  final List<Map<String, String>> _countries = [
    {'value': 'canada', 'label': 'كندا'},
    {'value': 'uk', 'label': 'المملكة المتحدة'},
    {'value': 'eg', 'label': 'مصر'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    // Set default day based on selected date
    _selectedDay = _days[_selectedDate.weekday % 7];
  }


  void _loadData() {
    // Load students list
    context.read<CalendarBloc>().repository.getStudentsList().then((students) {
      if (mounted) {
        setState(() {
          _students = students;
          _isLoadingStudents = false;
        });
      }
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _isLoadingStudents = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الطلاب: $error')),
        );
      }
    });

    // Load teachers list
    final state = context.read<CalendarBloc>().state;
    if (state is CalendarTeachersLoaded) {
      setState(() {
        _teachers = state.teachers
            .map((t) => {'id': t.id, 'name': t.name})
            .toList();
        _isLoadingTeachers = false;
      });
    } else {
      // Try to get from cached teachers
      final cachedTeachers = context.read<CalendarBloc>().cachedTeachers;
      if (cachedTeachers != null && cachedTeachers.isNotEmpty) {
        setState(() {
          _teachers = cachedTeachers
              .map((t) => {'id': t.id, 'name': t.name})
              .toList();
          _isLoadingTeachers = false;
        });
      } else {
        // Load teachers if not available
        context.read<CalendarBloc>().add(const LoadCalendarTeachers());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CalendarBloc, CalendarState>(
      listener: (context, state) {
        if (state is CalendarTeachersLoaded) {
          setState(() {
            _teachers = state.teachers
                .map((t) => {'id': t.id, 'name': t.name})
                .toList();
            _isLoadingTeachers = false;
          });
        } else if (state is CalendarOperationSuccess) {
          // Close dialog on success
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
            ),
          );
        } else if (state is CalendarError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: AlertDialog(
        title: const Text(
          'إضافة درس جديد',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Student selection with search
                if (_isLoadingStudents)
                  const Center(child: CircularProgressIndicator())
                else
                  FormField<String>(
                    initialValue: _selectedStudent,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'يرجى اختيار الطالب';
                      }
                      return null;
                    },
                    builder: (field) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Autocomplete<String>(
                            displayStringForOption: (option) => option,
                            optionsBuilder: (textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return _students;
                              }
                              final query = textEditingValue.text.toLowerCase();
                              return _students.where((student) {
                                return student.toLowerCase().contains(query);
                              }).toList();
                            },
                            onSelected: (value) {
                              setState(() {
                                _selectedStudent = value;
                              });
                              field.didChange(value);
                            },
                            fieldViewBuilder: (
                              context,
                              textEditingController,
                              focusNode,
                              onFieldSubmitted,
                            ) {
                              // Initialize controller text if student is already selected
                              if (_selectedStudent != null && textEditingController.text.isEmpty) {
                                textEditingController.text = _selectedStudent!;
                              }
                              return TextFormField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                onFieldSubmitted: (value) => onFieldSubmitted(),
                                decoration: InputDecoration(
                                  labelText: 'الطالب',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.person),
                                  suffixIcon: textEditingController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            textEditingController.clear();
                                            setState(() {
                                              _selectedStudent = null;
                                            });
                                            field.didChange(null);
                                          },
                                        )
                                      : null,
                                  errorText: field.errorText,
                                ),
                                onChanged: (value) {
                                  if (value.isEmpty) {
                                    setState(() {
                                      _selectedStudent = null;
                                    });
                                    field.didChange(null);
                                  }
                                },
                              );
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topRight,
                                child: Material(
                                  elevation: 4,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxHeight: 200),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      padding: EdgeInsets.zero,
                                      itemCount: options.length,
                                      itemBuilder: (context, index) {
                                        final option = options.elementAt(index);
                                        return InkWell(
                                          onTap: () => onSelected(option),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Text(option),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          if (field.errorText != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0, right: 12.0),
                              child: Text(
                                field.errorText!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                const SizedBox(height: AppSizes.spaceMd),

                // Teacher selection with search
                if (_isLoadingTeachers)
                  const Center(child: CircularProgressIndicator())
                else
                  FormField<int>(
                    initialValue: _selectedTeacherId,
                    validator: (value) {
                      if (value == null) {
                        return 'يرجى اختيار المعلم';
                      }
                      return null;
                    },
                    builder: (field) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Autocomplete<Map<String, dynamic>>(
                            displayStringForOption: (option) => option['name'] as String,
                            optionsBuilder: (textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return _teachers;
                              }
                              final query = textEditingValue.text.toLowerCase();
                              return _teachers.where((teacher) {
                                final name = (teacher['name'] as String).toLowerCase();
                                return name.contains(query);
                              }).toList();
                            },
                            onSelected: (value) {
                              setState(() {
                                _selectedTeacherId = value['id'] as int;
                                _selectedTeacherName = value['name'] as String;
                              });
                              field.didChange(value['id'] as int);
                            },
                            fieldViewBuilder: (
                              context,
                              textEditingController,
                              focusNode,
                              onFieldSubmitted,
                            ) {
                              // Initialize controller text if teacher is already selected
                              if (_selectedTeacherName != null && textEditingController.text.isEmpty) {
                                textEditingController.text = _selectedTeacherName!;
                              }
                              return TextFormField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                onFieldSubmitted: (value) => onFieldSubmitted(),
                                decoration: InputDecoration(
                                  labelText: 'المعلم',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.school),
                                  suffixIcon: textEditingController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            textEditingController.clear();
                                            setState(() {
                                              _selectedTeacherId = null;
                                              _selectedTeacherName = null;
                                            });
                                            field.didChange(null);
                                          },
                                        )
                                      : null,
                                  errorText: field.errorText,
                                ),
                                onChanged: (value) {
                                  if (value.isEmpty) {
                                    setState(() {
                                      _selectedTeacherId = null;
                                      _selectedTeacherName = null;
                                    });
                                    field.didChange(null);
                                  }
                                },
                              );
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topRight,
                                child: Material(
                                  elevation: 4,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxHeight: 200),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      padding: EdgeInsets.zero,
                                      itemCount: options.length,
                                      itemBuilder: (context, index) {
                                        final option = options.elementAt(index);
                                        return InkWell(
                                          onTap: () => onSelected(option),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Text(option['name'] as String),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          if (field.errorText != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0, right: 12.0),
                              child: Text(
                                field.errorText!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                const SizedBox(height: AppSizes.spaceMd),

                // Lesson Type Selection
                Card(
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        title: const Text('هذا اليوم فقط'),
                        subtitle: const Text('درس واحد في تاريخ محدد'),
                        value: 'one_time',
                        groupValue: _lessonType,
                        onChanged: (value) {
                          setState(() {
                            _lessonType = value!;
                          });
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('دائم'),
                        subtitle: const Text('درس متكرر أسبوعياً'),
                        value: 'permanent',
                        groupValue: _lessonType,
                        onChanged: (value) {
                          setState(() {
                            _lessonType = value!;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.spaceMd),

                // Date/Day selection based on lesson type
                if (_lessonType == 'one_time')
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() {
                          _selectedDate = date;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'التاريخ',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        DateFormat('yyyy-MM-dd', 'ar').format(_selectedDate),
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'اليوم',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        value: _selectedDay,
                        items: _days.map((day) {
                          return DropdownMenuItem(
                            value: day,
                            child: Text(_getArabicDayName(day)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedDay = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى اختيار اليوم';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSizes.spaceMd),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'الدولة',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.flag),
                        ),
                        value: _selectedCountry,
                        items: _countries.map((country) {
                          return DropdownMenuItem(
                            value: country['value'],
                            child: Text(country['label']!),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCountry = value!;
                          });
                        },
                      ),
                    ],
                  ),
                const SizedBox(height: AppSizes.spaceMd),

                // Time selection
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _startTime,
                          );
                          if (time != null) {
                            setState(() {
                              _startTime = time;
                              // Auto-adjust end time to be 1 hour after start time
                              _endTime = TimeOfDay(
                                hour: (time.hour + 1) % 24,
                                minute: time.minute,
                              );
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'من الساعة',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.access_time),
                          ),
                          child: Text(_formatTimeOfDay(_startTime)),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.spaceSm),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _endTime,
                          );
                          if (time != null) {
                            setState(() {
                              _endTime = time;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'إلى الساعة',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.access_time),
                          ),
                          child: Text(_formatTimeOfDay(_endTime)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: _saveLesson,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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

  void _saveLesson() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedStudent == null || _selectedTeacherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار الطالب والمعلم'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final startTimeStr = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}:00';
    final endTimeStr = '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}:00';

    if (_lessonType == 'one_time') {
      // Create exceptional class
      final exceptionalClass = CalendarExceptionalClassModel(
        id: 0, // Will be assigned by backend
        studentName: _selectedStudent!,
        date: _selectedDate,
        time: startTimeStr,
        teacherId: _selectedTeacherId!,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      context.read<CalendarBloc>().add(CreateExceptionalClass(exceptionalClass));
    } else {
      // Create permanent timetable
      if (_selectedDay == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى اختيار اليوم'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final timetable = CalendarTeacherTimetableModel(
        id: 0, // Will be assigned by backend
        teacherId: _selectedTeacherId!,
        day: _selectedDay!,
        startTime: startTimeStr,
        finishTime: endTimeStr,
        studentName: _selectedStudent!,
        country: _selectedCountry,
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      context.read<CalendarBloc>().add(CreateTeacherTimetable(timetable));
    }
  }
}

