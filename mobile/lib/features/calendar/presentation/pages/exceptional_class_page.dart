import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/api_service.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../../data/models/calendar_exceptional_class_model.dart';
import '../../data/models/calendar_teacher_model.dart';
import '../../data/datasources/calendar_remote_datasource.dart';
import '../../data/repositories/calendar_repository_impl.dart';

class ExceptionalClassPage extends StatefulWidget {
  final String studentName;
  final int teacherId;
  final String teacherName;

  const ExceptionalClassPage({
    super.key,
    required this.studentName,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  State<ExceptionalClassPage> createState() => _ExceptionalClassPageState();
}

class _ExceptionalClassPageState extends State<ExceptionalClassPage> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int? _selectedTeacherId;
  List<CalendarTeacherModel> _teachers = [];
  bool _isLoadingTeachers = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedTeacherId = widget.teacherId;
    _loadTeachers();
    _loadExceptionalClasses();
  }

  Future<void> _loadTeachers() async {
    setState(() {
      _isLoadingTeachers = true;
    });
    try {
      final apiService = ApiService();
      final remoteDataSource = CalendarRemoteDataSourceImpl(apiService);
      final repository = CalendarRepositoryImpl(remoteDataSource);
      final teachers = await repository.getCalendarTeachers();
      if (mounted) {
        setState(() {
          _teachers = teachers;
          _isLoadingTeachers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTeachers = false;
        });
      }
    }
  }

  void _loadExceptionalClasses() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CalendarBloc>().add(
              LoadStudentExceptionalClasses(widget.studentName),
            );
      }
    });
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

  String _convertTo24Hour(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('حصة استثنائية - ${widget.studentName}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
            // Reload exceptional classes
            _loadExceptionalClasses();
            // Reset form only if it was a create operation
            if (_isSubmitting) {
              setState(() {
                _selectedDate = null;
                _selectedTime = null;
                _isSubmitting = false;
              });
            }
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
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Add Form Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.spaceLg),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'إضافة حصة استثنائية',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSizes.spaceLg),
                          // Teacher Dropdown
                          DropdownButtonFormField<int>(
                            value: _selectedTeacherId,
                            decoration: const InputDecoration(
                              labelText: 'المعلم *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person_rounded),
                            ),
                            isExpanded: true,
                            items: _isLoadingTeachers
                                ? []
                                : _teachers.map((teacher) {
                                    return DropdownMenuItem<int>(
                                      value: teacher.id,
                                      child: Text(teacher.name),
                                    );
                                  }).toList(),
                            onChanged: _isLoadingTeachers
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedTeacherId = value;
                                    });
                                  },
                            validator: (value) {
                              if (value == null) {
                                return 'يرجى اختيار المعلم';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSizes.spaceMd),
                          // Date Picker
                          InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate ?? DateTime.now(),
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
                                labelText: 'التاريخ *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.calendar_today_rounded),
                              ),
                              child: Text(
                                _selectedDate != null
                                    ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
                                    : 'اختر التاريخ',
                                style: TextStyle(
                                  color: _selectedDate != null
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSizes.spaceMd),
                          // Time Picker
                          InkWell(
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: _selectedTime ?? TimeOfDay.now(),
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
                                  _selectedTime = time;
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'الوقت *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.access_time),
                              ),
                              child: Text(
                                _selectedTime != null
                                    ? _formatTimeOfDay(_selectedTime!)
                                    : 'اختر الوقت',
                                style: TextStyle(
                                  color: _selectedTime != null
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSizes.spaceLg),
                          // Submit Button
                          ElevatedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () {
                                    if (_formKey.currentState!.validate() &&
                                        _selectedDate != null &&
                                        _selectedTime != null &&
                                        _selectedTeacherId != null) {
                                      setState(() {
                                        _isSubmitting = true;
                                      });

                                      final exceptionalClass = CalendarExceptionalClassModel(
                                        id: 0,
                                        studentName: widget.studentName,
                                        date: _selectedDate!,
                                        time: _convertTo24Hour(_selectedTime!),
                                        teacherId: _selectedTeacherId!,
                                        createdAt: DateTime.now(),
                                        updatedAt: DateTime.now(),
                                      );

                                      context.read<CalendarBloc>().add(
                                            CreateExceptionalClass(exceptionalClass),
                                          );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceMd),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text('إضافة حصة استثنائية'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.spaceLg),
                // Existing Exceptional Classes
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.spaceLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'الحصص الاستثنائية الحالية',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSizes.spaceMd),
                        if (state is CalendarLoading)
                          const Center(child: CircularProgressIndicator())
                        else if (state is StudentExceptionalClassesLoaded)
                          _buildExceptionalClassesList(state.exceptionalClasses)
                        else if (state is CalendarError)
                          Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: AppColors.accentOrange,
                                ),
                                const SizedBox(height: AppSizes.spaceSm),
                                Text(
                                  state.message,
                                  style: const TextStyle(color: AppColors.textSecondary),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppSizes.spaceMd),
                                ElevatedButton(
                                  onPressed: () {
                                    _loadExceptionalClasses();
                                  },
                                  child: const Text('إعادة المحاولة'),
                                ),
                              ],
                            ),
                          )
                        else
                          const Center(
                            child: Text(
                              'لا توجد حصص استثنائية',
                              style: TextStyle(color: AppColors.textSecondary),
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

  Widget _buildExceptionalClassesList(List<CalendarExceptionalClassModel> classes) {
    if (classes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spaceLg),
          child: Column(
            children: [
              Icon(
                Icons.event_note_outlined,
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: AppSizes.spaceSm),
              Text(
                'لا توجد حصص استثنائية',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: classes.length,
      itemBuilder: (context, index) {
        final exceptionalClass = classes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: AppSizes.spaceSm),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.event_available_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            title: Text(
              exceptionalClass.teacherName ?? 'معلم',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'التاريخ: ${exceptionalClass.date.year}-${exceptionalClass.date.month.toString().padLeft(2, '0')}-${exceptionalClass.date.day.toString().padLeft(2, '0')}',
                ),
                Text(
                  'الوقت: ${_formatTime(exceptionalClass.time)}',
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.red),
              onPressed: () => _showDeleteConfirmation(exceptionalClass),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(CalendarExceptionalClassModel exceptionalClass) {
    // Capture the bloc before showing the dialog
    final bloc = context.read<CalendarBloc>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(
          'هل أنت متأكد من حذف الحصة الاستثنائية في ${exceptionalClass.date.year}-${exceptionalClass.date.month.toString().padLeft(2, '0')}-${exceptionalClass.date.day.toString().padLeft(2, '0')}؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              bloc.add(DeleteExceptionalClass(exceptionalClass.id));
              // Reload after delete
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  _loadExceptionalClasses();
                }
              });
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
}
