import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../common_widgets/custom_text_field.dart';
import '../../../../core/utils/api_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../features/students/data/datasources/student_remote_datasource.dart';
import '../../../../features/students/data/repositories/student_repository_impl.dart';
import '../../../../features/students/presentation/bloc/student_bloc.dart';
import '../../../../features/students/presentation/bloc/student_event.dart';
import '../../../../features/teachers/data/datasources/teacher_remote_datasource.dart';
import '../../../../features/teachers/data/repositories/teacher_repository_impl.dart';
import '../../../../features/teachers/presentation/bloc/teacher_bloc.dart';
import '../../../../features/teachers/presentation/bloc/teacher_event.dart';
import '../../data/datasources/course_remote_datasource.dart';
import '../../data/models/course_model.dart';
import '../../data/repositories/course_repository_impl.dart';
import '../bloc/course_bloc.dart';
import '../bloc/course_event.dart';
import '../bloc/course_state.dart';
import '../../../../features/students/presentation/bloc/student_state.dart';
import '../../../../features/teachers/presentation/bloc/teacher_state.dart';

class CourseFormPage extends StatefulWidget {
  final CourseModel? course;

  const CourseFormPage({super.key, this.course});

  @override
  State<CourseFormPage> createState() => _CourseFormPageState();
}

class _CourseFormPageState extends State<CourseFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  int? _selectedStudentId;
  int? _selectedTeacherId;

  @override
  void initState() {
    super.initState();
    if (widget.course != null) {
      _nameController.text = widget.course!.name;
      _selectedStudentId = widget.course!.studentId;
      _selectedTeacherId = widget.course!.teacherId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
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
            final dataSource = CourseRemoteDataSourceImpl(apiService);
            final repository = CourseRepositoryImpl(dataSource);
            return CourseBloc(repository);
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
            final studentDataSource = StudentRemoteDataSourceImpl(apiService);
            final studentRepository = StudentRepositoryImpl(studentDataSource);
            final bloc = StudentBloc(studentRepository);
            bloc.add(const LoadStudents());
            return bloc;
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
            final teacherDataSource = TeacherRemoteDataSourceImpl(apiService);
            final teacherRepository = TeacherRepositoryImpl(teacherDataSource);
            final bloc = TeacherBloc(teacherRepository);
            bloc.add(const LoadTeachers());
            return bloc;
          },
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.course == null 
              ? AppLocalizations.of(context)!.addCourse 
              : AppLocalizations.of(context)!.editCourse),
        ),
        body: BlocListener<CourseBloc, CourseState>(
          listener: (context, state) {
            if (state is CourseOperationSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message)),
              );
              context.pop();
            }
            if (state is CourseError) {
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
                  CustomTextField(
                    controller: _nameController,
                    label: AppLocalizations.of(context)!.courseName,
                    prefixIcon: const Icon(Icons.book),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!.courseNameIsRequired;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  BlocBuilder<StudentBloc, dynamic>(
                    builder: (context, state) {
                      if (state is StudentsLoaded) {
                        return DropdownButtonFormField<int>(
                          value: _selectedStudentId,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.student,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.school),
                          ),
                          items: state.students.map((student) {
                            return DropdownMenuItem(
                              value: student.id,
                              child: Text(student.name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedStudentId = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return AppLocalizations.of(context)!.pleaseSelectStudent;
                            }
                            return null;
                          },
                        );
                      }
                      return const CircularProgressIndicator();
                    },
                  ),
                  const SizedBox(height: 16),
                  BlocBuilder<TeacherBloc, dynamic>(
                    builder: (context, state) {
                      if (state is TeachersLoaded) {
                        return DropdownButtonFormField<int>(
                          value: _selectedTeacherId,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.teacher,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.person),
                          ),
                          items: state.teachers.map((teacher) {
                            return DropdownMenuItem(
                              value: teacher.id,
                              child: Text(teacher.name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedTeacherId = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return AppLocalizations.of(context)!.pleaseSelectTeacher;
                            }
                            return null;
                          },
                        );
                      }
                      return const CircularProgressIndicator();
                    },
                  ),
                  const SizedBox(height: 32),
                  BlocBuilder<CourseBloc, CourseState>(
                    builder: (context, state) {
                      final isLoading = state is CourseLoading;
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
                            : Text(widget.course == null 
                                ? AppLocalizations.of(context)!.createCourse 
                                : AppLocalizations.of(context)!.updateCourse),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submitForm(BuildContext context) {
    if (_formKey.currentState!.validate() &&
        _selectedStudentId != null &&
        _selectedTeacherId != null) {
      final course = CourseModel(
        id: widget.course?.id ?? 0,
        name: _nameController.text,
        studentId: _selectedStudentId!,
        teacherId: _selectedTeacherId!,
        createdAt: widget.course?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.course == null) {
        context.read<CourseBloc>().add(CreateCourse(course));
      } else {
        context.read<CourseBloc>().add(UpdateCourse(widget.course!.id, course));
      }
    }
  }
}

