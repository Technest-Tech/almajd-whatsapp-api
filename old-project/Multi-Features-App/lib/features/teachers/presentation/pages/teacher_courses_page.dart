import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui' as ui;
import '../../../../common_widgets/custom_text_field.dart';
import '../../../../core/utils/api_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/models/user_model.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../courses/data/datasources/course_remote_datasource.dart';
import '../../../courses/data/models/course_model.dart';
import '../../../courses/data/repositories/course_repository_impl.dart';
import '../../../courses/presentation/bloc/course_bloc.dart';
import '../../../courses/presentation/bloc/course_event.dart';
import '../../../courses/presentation/bloc/course_state.dart';
import '../../../courses/presentation/widgets/course_card.dart';
import '../../../students/data/datasources/student_remote_datasource.dart';
import '../../../students/data/repositories/student_repository_impl.dart';
import '../../../students/presentation/bloc/student_bloc.dart';
import '../../../students/presentation/bloc/student_event.dart';
import '../../../students/presentation/bloc/student_state.dart';

class TeacherCoursesPage extends StatelessWidget {
  const TeacherCoursesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: BlocProvider(
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
        final bloc = CourseBloc(repository);
        // Filter by current teacher - in real app, get teacher ID from auth
        bloc.add(const LoadCourses());
        return bloc;
      },
      child: BlocListener<CourseBloc, CourseState>(
        listener: (context, state) {
          if (state is CourseOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
            context.read<CourseBloc>().add(const LoadCourses());
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
        child: Builder(
          builder: (builderContext) => Scaffold(
            appBar: AppBar(
              title: const Text('دوراتي'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'إضافة دورة',
                  onPressed: () {
                    _showCreateCourseDialog(builderContext);
                  },
                ),
              ],
            ),
            body: BlocBuilder<CourseBloc, CourseState>(
              builder: (context, state) {
                if (state is CourseLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is CourseError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          state.message,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            context.read<CourseBloc>().add(const LoadCourses());
                          },
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  );
                }
                if (state is CoursesLoaded) {
                  if (state.courses.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.book_outlined,
                            size: 64,
                            color: Theme.of(context).hintColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد دورات مخصصة',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'اضغط على زر + لإضافة دورة',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).hintColor,
                                ),
                          ),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      context.read<CourseBloc>().add(const LoadCourses());
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.courses.length,
                      itemBuilder: (context, index) {
                        final course = state.courses[index];
                        return CourseCard(
                          course: course,
                          onTap: () {
                            context.push('/courses/${course.id}/lessons');
                          },
                          onEdit: null,
                          onDelete: null,
                        );
                      },
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, int courseId) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الدورة'),
          content: const Text('هل أنت متأكد من حذف هذه الدورة؟ سيتم حذف جميع الدروس المرتبطة بها أيضاً.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                context.read<CourseBloc>().add(DeleteCourse(courseId));
                Navigator.pop(context);
              },
              child: const Text('حذف', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateCourseDialog(BuildContext context) {
    // Read CourseBloc from the original context before showing dialog
    final courseBloc = context.read<CourseBloc>();
    
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
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
                final studentDataSource = StudentRemoteDataSourceImpl(apiService);
                final studentRepository = StudentRepositoryImpl(studentDataSource);
                final bloc = StudentBloc(studentRepository);
                bloc.add(const LoadStudents());
                return bloc;
              },
            ),
          ],
          child: _CreateCourseDialog(
            courseBloc: courseBloc,
          ),
        ),
      ),
    );
  }

  void _showEditCourseDialog(BuildContext context, CourseModel course) {
    // Read CourseBloc from the original context before showing dialog
    final courseBloc = context.read<CourseBloc>();
    
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
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
                final studentDataSource = StudentRemoteDataSourceImpl(apiService);
                final studentRepository = StudentRepositoryImpl(studentDataSource);
                final bloc = StudentBloc(studentRepository);
                bloc.add(const LoadStudents());
                return bloc;
              },
            ),
          ],
          child: _EditCourseDialog(
            courseBloc: courseBloc,
            course: course,
          ),
        ),
      ),
    );
  }
}

class _CreateCourseDialog extends StatefulWidget {
  final CourseBloc courseBloc;

  const _CreateCourseDialog({required this.courseBloc});

  @override
  State<_CreateCourseDialog> createState() => _CreateCourseDialogState();
}

class _CreateCourseDialogState extends State<_CreateCourseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  int? _selectedStudentId;
  int? _teacherId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTeacherId();
  }

  Future<void> _loadTeacherId() async {
    try {
      final userDataJson = await StorageService.getUserData();
      if (userDataJson != null && userDataJson.isNotEmpty) {
        final userData = jsonDecode(userDataJson) as Map<String, dynamic>;
        final user = UserModel.fromJson(userData);
        setState(() {
          _teacherId = int.tryParse(user.id);
        });
      }
    } catch (e) {
      debugPrint('Error loading teacher ID: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CourseBloc, CourseState>(
      bloc: widget.courseBloc,
      listener: (context, state) {
        if (state is CourseOperationSuccess) {
          Navigator.pop(context); // Close dialog
          widget.courseBloc.add(const LoadCourses()); // Refresh list
        }
        if (state is CourseError) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: AlertDialog(
        title: Text(AppLocalizations.of(context)!.addCourse),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  BlocBuilder<StudentBloc, StudentState>(
                    builder: (context, state) {
                      if (state is StudentLoading) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      if (state is StudentsLoaded) {
                        return DropdownButtonFormField<int>(
                          value: _selectedStudentId,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.student,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.school),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                          ),
                          isExpanded: true,
                          items: state.students.map((student) {
                            return DropdownMenuItem(
                              value: student.id,
                              child: Text(
                                student.name,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
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
                      if (state is StudentError) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            state.message,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.pop(context);
                  },
            child: const Text('إلغاء'),
          ),
          BlocBuilder<CourseBloc, CourseState>(
            bloc: widget.courseBloc,
            builder: (context, state) {
              final isLoading = state is CourseLoading || _isLoading;
              return ElevatedButton(
                onPressed: isLoading || _teacherId == null
                    ? null
                    : () => _submitForm(context),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(AppLocalizations.of(context)!.createCourse),
              );
            },
          ),
        ],
      ),
    );
  }

  void _submitForm(BuildContext context) {
    if (_formKey.currentState!.validate() &&
        _selectedStudentId != null &&
        _teacherId != null) {
      setState(() {
        _isLoading = true;
      });

      final course = CourseModel(
        id: 0,
        name: _nameController.text,
        studentId: _selectedStudentId!,
        teacherId: _teacherId!,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      widget.courseBloc.add(CreateCourse(course));
    }
  }
}

class _EditCourseDialog extends StatefulWidget {
  final CourseBloc courseBloc;
  final CourseModel course;

  const _EditCourseDialog({
    required this.courseBloc,
    required this.course,
  });

  @override
  State<_EditCourseDialog> createState() => _EditCourseDialogState();
}

class _EditCourseDialogState extends State<_EditCourseDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  int? _selectedStudentId;
  int? _teacherId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.course.name);
    _selectedStudentId = widget.course.studentId;
    _teacherId = widget.course.teacherId; // Use the course's teacher ID
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CourseBloc, CourseState>(
      bloc: widget.courseBloc,
      listener: (context, state) {
        if (state is CourseOperationSuccess) {
          Navigator.pop(context); // Close dialog
          widget.courseBloc.add(const LoadCourses()); // Refresh list
        }
        if (state is CourseError) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: AlertDialog(
        title: Text(AppLocalizations.of(context)!.editCourse),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  BlocBuilder<StudentBloc, StudentState>(
                    builder: (context, state) {
                      if (state is StudentLoading) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      if (state is StudentsLoaded) {
                        return DropdownButtonFormField<int>(
                          value: _selectedStudentId,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.student,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.school),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                          ),
                          isExpanded: true,
                          items: state.students.map((student) {
                            return DropdownMenuItem(
                              value: student.id,
                              child: Text(
                                student.name,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
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
                      if (state is StudentError) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            state.message,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.pop(context);
                  },
            child: const Text('إلغاء'),
          ),
          BlocBuilder<CourseBloc, CourseState>(
            bloc: widget.courseBloc,
            builder: (context, state) {
              final isLoading = state is CourseLoading || _isLoading;
              return ElevatedButton(
                onPressed: isLoading || _teacherId == null
                    ? null
                    : () => _submitForm(context),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(AppLocalizations.of(context)!.updateCourse),
              );
            },
          ),
        ],
      ),
    );
  }

  void _submitForm(BuildContext context) {
    if (_formKey.currentState!.validate() &&
        _selectedStudentId != null &&
        _teacherId != null) {
      setState(() {
        _isLoading = true;
      });

      final course = CourseModel(
        id: widget.course.id,
        name: _nameController.text,
        studentId: _selectedStudentId!,
        teacherId: _teacherId!,
        createdAt: widget.course.createdAt,
        updatedAt: DateTime.now(),
      );

      widget.courseBloc.add(UpdateCourse(widget.course.id, course));
    }
  }
}

