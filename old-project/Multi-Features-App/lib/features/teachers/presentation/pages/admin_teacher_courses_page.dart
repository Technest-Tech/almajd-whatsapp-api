import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui' as ui;
import '../../../../common_widgets/custom_text_field.dart';
import '../../../../core/utils/api_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../courses/data/datasources/course_remote_datasource.dart';
import '../../../courses/data/models/course_model.dart';
import '../../../courses/data/repositories/course_repository_impl.dart';
import '../../../courses/presentation/bloc/course_bloc.dart';
import '../../../courses/presentation/bloc/course_event.dart';
import '../../../courses/presentation/bloc/course_state.dart';
import '../../../courses/presentation/widgets/course_card.dart';
import '../../../students/data/models/student_model.dart';
import '../../data/datasources/teacher_remote_datasource.dart';
import '../../data/models/teacher_model.dart';
import '../../data/repositories/teacher_repository_impl.dart';
import '../bloc/teacher_bloc.dart';
import '../bloc/teacher_event.dart';
import '../bloc/teacher_state.dart';

class AdminTeacherCoursesPage extends StatelessWidget {
  final int teacherId;

  const AdminTeacherCoursesPage({
    super.key,
    required this.teacherId,
  });

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
              final dataSource = CourseRemoteDataSourceImpl(apiService);
              final repository = CourseRepositoryImpl(dataSource);
              final bloc = CourseBloc(repository);
              // Filter courses by teacher ID
              bloc.add(LoadCourses(teacherId: teacherId));
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
              final dataSource = TeacherRemoteDataSourceImpl(apiService);
              final repository = TeacherRepositoryImpl(dataSource);
              final bloc = TeacherBloc(repository);
              bloc.add(LoadTeacher(teacherId));
              return bloc;
            },
          ),
        ],
        child: BlocBuilder<TeacherBloc, TeacherState>(
          builder: (context, teacherState) {
            String teacherName = 'المعلم';
            if (teacherState is TeacherLoaded) {
              teacherName = teacherState.teacher.name;
            }
            
            return Scaffold(
              appBar: AppBar(
                title: Text('دورات $teacherName'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
                actions: [
                  Builder(
                    builder: (builderContext) => IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: 'إضافة دورة',
                      onPressed: () {
                        _showCreateCourseDialog(builderContext);
                      },
                    ),
                  ),
                ],
              ),
              body: BlocListener<CourseBloc, CourseState>(
                listener: (context, state) {
                  if (state is CourseOperationSuccess) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: Colors.green,
                      ),
                    );
                    context.read<CourseBloc>().add(LoadCourses(teacherId: teacherId));
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
                  builder: (builderContext) => Stack(
                    children: [
                      BlocBuilder<CourseBloc, CourseState>(
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
                                      context.read<CourseBloc>().add(LoadCourses(teacherId: teacherId));
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
                                      'لا توجد دورات',
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
                                context.read<CourseBloc>().add(LoadCourses(teacherId: teacherId));
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
                                    onEdit: () {
                                      _showEditCourseDialog(builderContext, course);
                                    },
                                    onDelete: () {
                                      _showDeleteDialog(builderContext, course.id);
                                    },
                                  );
                                },
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
            );
          },
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, int courseId) {
    // Read CourseBloc from the original context before showing dialog
    final courseBloc = context.read<CourseBloc>();
    
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الدورة'),
          content: const Text('هل أنت متأكد من حذف هذه الدورة؟ سيتم حذف جميع الدروس المرتبطة بها أيضاً.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                courseBloc.add(DeleteCourse(courseId));
                Navigator.pop(dialogContext);
              },
              child: const Text('حذف', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateCourseDialog(BuildContext context) {
    // Read CourseBloc and TeacherBloc from the original context before showing dialog
    final courseBloc = context.read<CourseBloc>();
    final teacherBloc = context.read<TeacherBloc>();
    
    // Get assigned students from teacher state
    List<StudentModel> assignedStudents = [];
    if (teacherBloc.state is TeacherLoaded) {
      assignedStudents = (teacherBloc.state as TeacherLoaded).teacher.assignedStudents;
    }
    
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: _CreateCourseDialog(
          courseBloc: courseBloc,
          teacherId: teacherId,
          assignedStudents: assignedStudents,
        ),
      ),
    );
  }

  void _showEditCourseDialog(BuildContext context, CourseModel course) {
    // Read CourseBloc and TeacherBloc from the original context before showing dialog
    final courseBloc = context.read<CourseBloc>();
    final teacherBloc = context.read<TeacherBloc>();
    
    // Get assigned students from teacher state
    List<StudentModel> assignedStudents = [];
    if (teacherBloc.state is TeacherLoaded) {
      assignedStudents = (teacherBloc.state as TeacherLoaded).teacher.assignedStudents;
    }
    
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: _EditCourseDialog(
          courseBloc: courseBloc,
          course: course,
          teacherId: teacherId,
          assignedStudents: assignedStudents,
        ),
      ),
    );
  }
}

class _CreateCourseDialog extends StatefulWidget {
  final CourseBloc courseBloc;
  final int teacherId;
  final List<StudentModel> assignedStudents;

  const _CreateCourseDialog({
    required this.courseBloc,
    required this.teacherId,
    required this.assignedStudents,
  });

  @override
  State<_CreateCourseDialog> createState() => _CreateCourseDialogState();
}

class _CreateCourseDialogState extends State<_CreateCourseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  int? _selectedStudentId;
  bool _isLoading = false;

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
          widget.courseBloc.add(LoadCourses(teacherId: widget.teacherId)); // Refresh list
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
                    hint: 'أدخل اسم الدورة',
                    prefixIcon: const Icon(Icons.book),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!.courseNameIsRequired;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  widget.assignedStudents.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'لا يوجد طلاب مخصصين لهذا المعلم',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
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
                              items: widget.assignedStudents.map((student) {
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
                onPressed: isLoading || _selectedStudentId == null || widget.assignedStudents.isEmpty
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
        _selectedStudentId != null) {
      setState(() {
        _isLoading = true;
      });

      final course = CourseModel(
        id: 0,
        name: _nameController.text,
        studentId: _selectedStudentId!,
        teacherId: widget.teacherId,
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
  final int teacherId;
  final List<StudentModel> assignedStudents;

  const _EditCourseDialog({
    required this.courseBloc,
    required this.course,
    required this.teacherId,
    required this.assignedStudents,
  });

  @override
  State<_EditCourseDialog> createState() => _EditCourseDialogState();
}

class _EditCourseDialogState extends State<_EditCourseDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  int? _selectedStudentId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.course.name);
    _selectedStudentId = widget.course.studentId;
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
          widget.courseBloc.add(LoadCourses(teacherId: widget.teacherId)); // Refresh list
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
                  widget.assignedStudents.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'لا يوجد طلاب مخصصين لهذا المعلم',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
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
                              items: widget.assignedStudents.map((student) {
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
                onPressed: isLoading || _selectedStudentId == null || widget.assignedStudents.isEmpty
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
        _selectedStudentId != null) {
      setState(() {
        _isLoading = true;
      });

      final course = CourseModel(
        id: widget.course.id,
        name: _nameController.text,
        studentId: _selectedStudentId!,
        teacherId: widget.teacherId,
        createdAt: widget.course.createdAt,
        updatedAt: DateTime.now(),
      );

      widget.courseBloc.add(UpdateCourse(widget.course.id, course));
    }
  }
}
