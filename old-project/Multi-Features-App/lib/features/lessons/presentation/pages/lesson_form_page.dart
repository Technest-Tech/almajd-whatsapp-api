import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../../../../common_widgets/custom_text_field.dart';
import '../../../../core/utils/api_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../features/courses/data/datasources/course_remote_datasource.dart';
import '../../../../features/courses/data/repositories/course_repository_impl.dart';
import '../../../../features/courses/presentation/bloc/course_bloc.dart';
import '../../../../features/courses/presentation/bloc/course_event.dart';
import '../../../../features/courses/presentation/bloc/course_state.dart';
import '../../data/datasources/lesson_remote_datasource.dart';
import '../../data/models/lesson_model.dart';
import '../../data/repositories/lesson_repository_impl.dart';
import '../bloc/lesson_bloc.dart';
import '../bloc/lesson_event.dart';
import '../bloc/lesson_state.dart';

class LessonFormPage extends StatefulWidget {
  final LessonModel? lesson;
  final int? courseId;

  const LessonFormPage({super.key, this.lesson, this.courseId});

  @override
  State<LessonFormPage> createState() => _LessonFormPageState();
}

class _LessonFormPageState extends State<LessonFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _durationController = TextEditingController();
  final _notesController = TextEditingController();
  final _dutyController = TextEditingController();
  
  int? _selectedCourseId;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.lesson != null) {
      _selectedCourseId = widget.lesson!.courseId;
      _selectedDate = widget.lesson!.date;
      _durationController.text = widget.lesson!.duration.toString();
      _notesController.text = widget.lesson!.notes ?? '';
      _dutyController.text = widget.lesson!.duty?.toString() ?? '';
    } else if (widget.courseId != null) {
      _selectedCourseId = widget.courseId;
    }
  }

  @override
  void dispose() {
    _durationController.dispose();
    _notesController.dispose();
    _dutyController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) {
              final apiService = ApiService();
              final token = StorageService.getToken();
              token.then((t) {
                if (t != null) {
                  apiService.setAuthToken(t);
                }
              });
              final dataSource = LessonRemoteDataSourceImpl(apiService);
              final repository = LessonRepositoryImpl(dataSource);
              return LessonBloc(repository);
            },
          ),
          BlocProvider(
            create: (context) {
              final apiService = ApiService();
              final token = StorageService.getToken();
              token.then((t) {
                if (t != null) {
                  apiService.setAuthToken(t);
                }
              });
              final courseDataSource = CourseRemoteDataSourceImpl(apiService);
              final courseRepository = CourseRepositoryImpl(courseDataSource);
              final bloc = CourseBloc(courseRepository);
              bloc.add(const LoadCourses());
              return bloc;
            },
          ),
        ],
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.lesson == null 
                ? AppLocalizations.of(context)!.addLesson 
                : AppLocalizations.of(context)!.editLesson),
          ),
          body: BlocListener<LessonBloc, LessonState>(
            listener: (context, state) {
            if (state is LessonOperationSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message)),
              );
              context.pop();
            }
            if (state is LessonError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BlocBuilder<CourseBloc, dynamic>(
                    builder: (context, state) {
                      if (state is CoursesLoaded) {
                        final isCourseLocked = widget.courseId != null && widget.lesson == null;
                        return DropdownButtonFormField<int>(
                          value: _selectedCourseId,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.course,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.book),
                          ),
                          items: state.courses.map((course) {
                            return DropdownMenuItem(
                              value: course.id,
                              child: Text(course.name),
                            );
                          }).toList(),
                          onChanged: isCourseLocked ? null : (value) {
                            setState(() {
                              _selectedCourseId = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return AppLocalizations.of(context)!.pleaseSelectCourse;
                            }
                            return null;
                          },
                        );
                      }
                      return const CircularProgressIndicator();
                    },
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => _selectDate(context),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.date,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        DateFormat('MMM dd, yyyy').format(_selectedDate),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _durationController,
                    label: AppLocalizations.of(context)!.durationMinutes,
                    prefixIcon: const Icon(Icons.access_time),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!.durationIsRequired;
                      }
                      final duration = int.tryParse(value);
                      if (duration == null || duration <= 0) {
                        return AppLocalizations.of(context)!.invalidDuration;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _notesController,
                    label: AppLocalizations.of(context)!.notes,
                    prefixIcon: const Icon(Icons.note),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _dutyController,
                    label: AppLocalizations.of(context)!.dutyPayment,
                    prefixIcon: const Icon(Icons.attach_money),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final duty = double.tryParse(value);
                        if (duty == null || duty < 0) {
                          return AppLocalizations.of(context)!.invalidDutyAmount;
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  BlocBuilder<LessonBloc, LessonState>(
                    builder: (context, state) {
                      final isLoading = state is LessonLoading;
                      return ElevatedButton(
                        onPressed: isLoading ? null : () => _submitForm(context),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(widget.lesson == null 
                                ? AppLocalizations.of(context)!.createLesson 
                                : AppLocalizations.of(context)!.updateLesson),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  void _submitForm(BuildContext context) {
    if (_formKey.currentState!.validate() && _selectedCourseId != null) {
      final lesson = LessonModel(
        id: widget.lesson?.id ?? 0,
        courseId: _selectedCourseId!,
        date: _selectedDate,
        duration: int.parse(_durationController.text),
        status: 'present', // Always 'present' by default
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        duty: _dutyController.text.isEmpty
            ? null
            : double.tryParse(_dutyController.text),
        createdBy: widget.lesson?.createdBy ?? 1, // Will be set by backend
        createdAt: widget.lesson?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.lesson == null) {
        context.read<LessonBloc>().add(CreateLesson(lesson));
      } else {
        context.read<LessonBloc>().add(UpdateLesson(widget.lesson!.id, lesson));
      }
    }
  }
}

