import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../../../../common_widgets/scaffold_with_bottom_bar.dart';
import '../../../../common_widgets/custom_text_field.dart';
import '../../../../core/utils/api_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/datasources/lesson_remote_datasource.dart';
import '../../data/models/lesson_model.dart';
import '../../data/repositories/lesson_repository_impl.dart';
import '../bloc/lesson_bloc.dart';
import '../bloc/lesson_event.dart';
import '../bloc/lesson_state.dart';
import '../widgets/lesson_card.dart';
import '../../../courses/data/datasources/course_remote_datasource.dart';
import '../../../courses/data/repositories/course_repository_impl.dart';
import '../../../courses/presentation/bloc/course_bloc.dart';
import '../../../courses/presentation/bloc/course_event.dart';
import '../../../courses/presentation/bloc/course_state.dart';
import '../../services/lesson_settings_service.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/models/user_role.dart';
import 'dart:convert';

class LessonsListPage extends StatefulWidget {
  final int? courseId;

  const LessonsListPage({super.key, this.courseId});

  @override
  State<LessonsListPage> createState() => _LessonsListPageState();
}

class _LessonsListPageState extends State<LessonsListPage> {
  late DateTime _selectedDate;
  late int _selectedYear;
  late int _selectedMonth;
  bool _teachersCanEditLessons = true;
  bool _teachersCanDeleteLessons = true;
  bool _teachersCanAddPastLessons = false;
  bool _isTeacher = false;
  bool _isAdmin = false;
  bool _settingsLoaded = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = now;
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _loadLessonSettings();
  }

  Future<void> _loadLessonSettings({bool forceRefresh = false}) async {
    try {
      // Check user role
      final userDataJson = await StorageService.getUserData();
      UserModel? user;
      if (userDataJson != null && userDataJson.isNotEmpty) {
        final userData = jsonDecode(userDataJson) as Map<String, dynamic>;
        user = UserModel.fromJson(userData);
      }
      
      final isAdminUser = user?.role == UserRole.admin;
      final isTeacherUser = user?.role == UserRole.teacher;
      
      if (isAdminUser) {
        // Admin: enable all actions by default
        if (mounted) {
          setState(() {
            _isAdmin = true;
            _isTeacher = false;
            _teachersCanEditLessons = true;
            _teachersCanDeleteLessons = true;
            _teachersCanAddPastLessons = true; // Admins can add past lessons
            _settingsLoaded = true;
          });
        }
      } else if (isTeacherUser) {
        // Teacher: use settings
        final settings = await LessonSettingsService.getLessonSettings(forceRefresh: forceRefresh);
        if (mounted) {
          setState(() {
            _isAdmin = false;
            _isTeacher = true;
            _teachersCanEditLessons = settings['teachers_can_edit_lessons'] ?? true;
            _teachersCanDeleteLessons = settings['teachers_can_delete_lessons'] ?? true;
            _teachersCanAddPastLessons = settings['teachers_can_add_past_lessons'] ?? false;
            _settingsLoaded = true;
          });
        }
      } else {
        // Not teacher or admin
        if (mounted) {
          setState(() {
            _isAdmin = false;
            _isTeacher = false;
            _settingsLoaded = true;
          });
        }
      }
    } catch (e) {
      // On error, default to disabled for teachers
      if (mounted) {
        setState(() {
          _isAdmin = false;
          _isTeacher = true; // Assume teacher if error
          _teachersCanEditLessons = false;
          _teachersCanDeleteLessons = false;
          _teachersCanAddPastLessons = false;
          _settingsLoaded = true;
        });
      }
    }
  }

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
          final dataSource = LessonRemoteDataSourceImpl(apiService);
          final repository = LessonRepositoryImpl(dataSource);
          final bloc = LessonBloc(repository);
          bloc.add(LoadLessons(
            courseId: widget.courseId,
            year: _selectedYear,
            month: _selectedMonth,
          ));
          return bloc;
        },
        child: Builder(
          builder: (builderContext) => widget.courseId != null
              ? Scaffold(
                  appBar: AppBar(
                    title: const Text('الدروس'),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: 'إضافة درس',
                        onPressed: () {
                          _showCreateLessonDialog(builderContext);
                        },
                      ),
                    ],
                  ),
                  body: Column(
                    children: [
                      _buildDateSelector(builderContext),
                      Expanded(
                        child: BlocBuilder<LessonBloc, LessonState>(
                        builder: (context, state) {
                          if (state is LessonLoading) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (state is LessonError) {
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
                                    onPressed: () => _loadLessons(context),
                                    child: const Text('إعادة المحاولة'),
                                  ),
                                ],
                              ),
                            );
                          }
                          if (state is LessonsLoaded) {
                            // Wait for settings to load before showing lessons
                            if (!_settingsLoaded) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            
                            if (state.lessons.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.event_note_outlined,
                                      size: 64,
                                      color: Theme.of(context).hintColor,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'لا توجد دروس',
                                      style: Theme.of(context).textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'اضغط على زر + لإضافة درس',
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
                                _loadLessons(context);
                                await _loadLessonSettings(forceRefresh: true); // Force reload settings on refresh
                              },
                              child: ListView.builder(
                                itemCount: state.lessons.length,
                                itemBuilder: (context, index) {
                                  final lesson = state.lessons[index];
                                  return LessonCard(
                                    lesson: lesson,
                                    onEdit: (_isAdmin || (_isTeacher && _teachersCanEditLessons))
                                        ? () {
                                            _showEditLessonDialog(builderContext, lesson);
                                          }
                                        : null,
                                    onDelete: (_isAdmin || (_isTeacher && _teachersCanDeleteLessons))
                                        ? () {
                                            _showDeleteDialog(builderContext, lesson.id);
                                          }
                                        : null,
                                  );
                                },
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ],
                ),
              )
              : ScaffoldWithBottomBar(
                  title: 'جميع الدروس',
                  floatingActionButton: FloatingActionButton(
                    onPressed: () {
                      _showCreateLessonDialog(builderContext);
                    },
                    child: const Icon(Icons.add),
                  ),
                  body: Column(
                    children: [
                      _buildDateSelector(builderContext),
                      Expanded(
                        child: BlocBuilder<LessonBloc, LessonState>(
                        builder: (context, state) {
                          if (state is LessonLoading) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (state is LessonError) {
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
                                    onPressed: () => _loadLessons(context),
                                    child: const Text('إعادة المحاولة'),
                                  ),
                                ],
                              ),
                            );
                          }
                          if (state is LessonsLoaded) {
                            // Wait for settings to load before showing lessons
                            if (!_settingsLoaded) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            
                            if (state.lessons.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.event_note_outlined,
                                      size: 64,
                                      color: Theme.of(context).hintColor,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'لا توجد دروس',
                                      style: Theme.of(context).textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'اضغط على زر + لإضافة درس',
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
                                _loadLessons(context);
                                await _loadLessonSettings(forceRefresh: true); // Force reload settings on refresh
                              },
                              child: ListView.builder(
                                itemCount: state.lessons.length,
                                itemBuilder: (context, index) {
                                  final lesson = state.lessons[index];
                                  return LessonCard(
                                    lesson: lesson,
                                    onEdit: (_isAdmin || (_isTeacher && _teachersCanEditLessons))
                                        ? () {
                                            _showEditLessonDialog(builderContext, lesson);
                                          }
                                        : null,
                                    onDelete: (_isAdmin || (_isTeacher && _teachersCanDeleteLessons))
                                        ? () {
                                            _showDeleteDialog(builderContext, lesson.id);
                                          }
                                        : null,
                                  );
                                },
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context) {
    // Arabic month names
    final arabicMonths = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous month button
          _buildNavigationButton(
            context,
            icon: Icons.arrow_forward_ios,
            onPressed: () {
              setState(() {
                if (_selectedMonth == 12) {
                  _selectedMonth = 1;
                  _selectedYear++;
                } else {
                  _selectedMonth++;
                }
                _selectedDate = DateTime(_selectedYear, _selectedMonth);
              });
              _loadLessons(context);
            },
          ),
          
          // Date display section
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
            children: [
                // Clickable month name
                Flexible(
                  child: InkWell(
                    onTap: () => _showMonthPicker(context, arabicMonths),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              arabicMonths[_selectedMonth - 1],
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Clickable year
                InkWell(
                  onTap: () => _showYearPicker(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                        width: 1.5,
                    ),
              ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
              Text(
                '$_selectedYear',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 16,
                          color: Theme.of(context).colorScheme.secondary,
              ),
            ],
          ),
                  ),
                ),
              ],
            ),
          ),
          
          // Next month button
          _buildNavigationButton(
            context,
            icon: Icons.arrow_back_ios,
            onPressed: () {
              setState(() {
                if (_selectedMonth == 1) {
                  _selectedMonth = 12;
                  _selectedYear--;
                } else {
                  _selectedMonth--;
                }
                _selectedDate = DateTime(_selectedYear, _selectedMonth);
              });
              _loadLessons(context);
            },
          ),
        ],
      ),
    );
  }

  void _showMonthPicker(BuildContext context, List<String> arabicMonths) {
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('اختر الشهر'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(12, (index) {
                  final monthNumber = index + 1;
                  final isSelected = monthNumber == _selectedMonth;
                  return ListTile(
                    title: Text(
                      arabicMonths[index],
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected 
                            ? Theme.of(context).colorScheme.primary 
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedMonth = monthNumber;
                        _selectedDate = DateTime(_selectedYear, _selectedMonth);
                      });
                      Navigator.pop(dialogContext);
                      _loadLessons(context);
                    },
                  );
                }),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
          ],
        ),
      ),
    );
  }

  void _showYearPicker(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = List.generate(10, (index) => currentYear - 5 + index);
    
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('اختر السنة'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: years.map((year) {
                  final isSelected = year == _selectedYear;
                  return ListTile(
                    title: Text(
                      '$year',
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected 
                            ? Theme.of(context).colorScheme.primary 
                            : Theme.of(context).colorScheme.onSurface,
                        fontSize: 18,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedYear = year;
                        _selectedDate = DateTime(_selectedYear, _selectedMonth);
                      });
                      Navigator.pop(dialogContext);
                      _loadLessons(context);
                    },
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  void _loadLessons(BuildContext context) {
    context.read<LessonBloc>().add(
          LoadLessons(
            courseId: widget.courseId,
            year: _selectedYear,
            month: _selectedMonth,
          ),
        );
  }

  void _showDeleteDialog(BuildContext context, int lessonId) {
    // Read LessonBloc from the original context before showing dialog
    final lessonBloc = context.read<LessonBloc>();
    
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الدرس'),
          content: const Text('هل أنت متأكد من حذف هذا الدرس؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                lessonBloc.add(DeleteLesson(lessonId));
                Navigator.pop(dialogContext);
              },
              child: const Text('حذف', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateLessonDialog(BuildContext context) {
    // Read LessonBloc from the original context before showing dialog
    final lessonBloc = context.read<LessonBloc>();
    
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
                final courseDataSource = CourseRemoteDataSourceImpl(apiService);
                final courseRepository = CourseRepositoryImpl(courseDataSource);
                final bloc = CourseBloc(courseRepository);
                bloc.add(const LoadCourses());
                return bloc;
              },
            ),
          ],
          child: _CreateLessonDialog(
            lessonBloc: lessonBloc,
            courseId: widget.courseId,
            canAddPastLessons: _isAdmin || _teachersCanAddPastLessons,
            isTeacher: _isTeacher,
            isAdmin: _isAdmin,
          ),
        ),
      ),
    );
  }

  void _showEditLessonDialog(BuildContext context, LessonModel lesson) {
    // Read LessonBloc from the original context before showing dialog
    final lessonBloc = context.read<LessonBloc>();
    
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
                final courseDataSource = CourseRemoteDataSourceImpl(apiService);
                final courseRepository = CourseRepositoryImpl(courseDataSource);
                final bloc = CourseBloc(courseRepository);
                bloc.add(const LoadCourses());
                return bloc;
              },
            ),
          ],
          child: _EditLessonDialog(
            lessonBloc: lessonBloc,
            lesson: lesson,
            courseId: widget.courseId,
            canAddPastLessons: _isAdmin || _teachersCanAddPastLessons,
            isTeacher: _isTeacher,
            isAdmin: _isAdmin,
          ),
        ),
      ),
    );
  }
}

class _CreateLessonDialog extends StatefulWidget {
  final LessonBloc lessonBloc;
  final int? courseId;
  final bool canAddPastLessons;
  final bool isTeacher;
  final bool isAdmin;

  const _CreateLessonDialog({
    required this.lessonBloc,
    this.courseId,
    required this.canAddPastLessons,
    required this.isTeacher,
    required this.isAdmin,
  });

  @override
  State<_CreateLessonDialog> createState() => _CreateLessonDialogState();
}

class _CreateLessonDialogState extends State<_CreateLessonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  
  int? _selectedCourseId;
  DateTime _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day); // Auto set to today (normalized to start of day)
  int? _selectedDuration; // Duration in minutes
  String _selectedStatus = 'present'; // Default to present

  // Duration options in minutes: 30, 45, 60, 75 (1h 15m), 90 (1h 30m), 120 (2h), 135 (2h 15m), 150 (2h 30m), 180 (3h)
  final Map<int, String> _durationOptions = {
    30: '30 دقيقة',
    45: '45 دقيقة',
    60: '1 ساعة',
    75: '1 ساعة و 15 دقيقة',
    90: '1 ساعة و 30 دقيقة',
    120: '2 ساعة',
    135: '2 ساعة و 15 دقيقة',
    150: '2 ساعة و 30 دقيقة',
    180: '3 ساعة',
  };

  @override
  void initState() {
    super.initState();
    if (widget.courseId != null) {
      _selectedCourseId = widget.courseId;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    // Determine minimum date based on settings
    DateTime firstDate;
    if (widget.isAdmin) {
      // Admins can add lessons with any date
      firstDate = DateTime.now().subtract(const Duration(days: 365));
    } else if (widget.isTeacher && !widget.canAddPastLessons) {
      // Teachers can only add lessons from today onwards
      firstDate = DateTime.now();
    } else {
      // Allow past dates if setting allows
      firstDate = DateTime.now().subtract(const Duration(days: 365));
    }
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ar', 'SA'), // Arabic locale
      builder: (context, child) {
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        // Normalize date to start of day to avoid timezone issues
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LessonBloc, LessonState>(
      bloc: widget.lessonBloc,
      listener: (context, state) {
        if (state is LessonOperationSuccess) {
          Navigator.pop(context); // Close dialog
          widget.lessonBloc.add(LoadLessons(
            courseId: widget.courseId,
            year: _selectedDate.year,
            month: _selectedDate.month,
          )); // Refresh list
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
      child: AlertDialog(
        title: Text(AppLocalizations.of(context)!.addLesson),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.courseId == null)
                    BlocBuilder<CourseBloc, CourseState>(
                      builder: (context, state) {
                        if (state is CoursesLoaded) {
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
                            onChanged: (value) {
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
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        );
                      },
                    ),
                  if (widget.courseId == null) const SizedBox(height: 16),
                  // Date field - clickable to open date picker
                  InkWell(
                    onTap: () => _selectDate(context),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.date,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.calendar_today),
                        suffixIcon: const Icon(Icons.arrow_drop_down),
                      ),
                      child: Text(
                        DateFormat('yyyy-MM-dd').format(_selectedDate),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Duration dropdown
                  DropdownButtonFormField<int>(
                    value: _selectedDuration,
                    decoration: InputDecoration(
                      labelText: 'المدة',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    prefixIcon: const Icon(Icons.access_time),
                    ),
                    items: _durationOptions.entries.map((entry) {
                      return DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedDuration = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'الرجاء اختيار المدة';
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
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('إلغاء'),
          ),
          BlocBuilder<LessonBloc, LessonState>(
            bloc: widget.lessonBloc,
            builder: (context, state) {
              final isLoading = state is LessonLoading;
              return ElevatedButton(
                onPressed: isLoading ? null : () => _submitForm(context),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(AppLocalizations.of(context)!.createLesson),
              );
            },
          ),
        ],
      ),
    );
  }

  void _submitForm(BuildContext context) {
    if (_formKey.currentState!.validate() && 
        _selectedCourseId != null && 
        _selectedDuration != null) {
      final lesson = LessonModel(
        id: 0,
        courseId: _selectedCourseId!,
        date: _selectedDate,
        duration: _selectedDuration!,
        status: _selectedStatus,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        duty: null, // Will be calculated automatically by backend
        createdBy: 1, // Will be set by backend
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      widget.lessonBloc.add(CreateLesson(lesson));
    }
  }
}

class _EditLessonDialog extends StatefulWidget {
  final LessonBloc lessonBloc;
  final LessonModel lesson;
  final int? courseId;
  final bool canAddPastLessons;
  final bool isTeacher;
  final bool isAdmin;

  const _EditLessonDialog({
    required this.lessonBloc,
    required this.lesson,
    this.courseId,
    required this.canAddPastLessons,
    required this.isTeacher,
    required this.isAdmin,
  });

  @override
  State<_EditLessonDialog> createState() => _EditLessonDialogState();
}

class _EditLessonDialogState extends State<_EditLessonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  int? _selectedDuration;
  String _selectedStatus = 'present';

  // Duration options in minutes
  final Map<int, String> _durationOptions = {
    30: '30 دقيقة',
    45: '45 دقيقة',
    60: '1 ساعة',
    75: '1 ساعة و 15 دقيقة',
    90: '1 ساعة و 30 دقيقة',
    120: '2 ساعة',
    135: '2 ساعة و 15 دقيقة',
    150: '2 ساعة و 30 دقيقة',
    180: '3 ساعة',
  };

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.lesson.date;
    _selectedDuration = widget.lesson.duration;
    _selectedStatus = widget.lesson.status;
    _notesController.text = widget.lesson.notes ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    // For editing, allow past dates if the original lesson date was in the past
    // or if settings allow past dates
    DateTime firstDate;
    final originalDate = widget.lesson.date;
    final today = DateTime.now();
    
    if (widget.isAdmin) {
      // Admins can edit lessons with any date
      firstDate = DateTime.now().subtract(const Duration(days: 365));
    } else if (widget.isTeacher && !widget.canAddPastLessons) {
      // If can't add past lessons, only allow dates from today onwards
      // But if editing an existing lesson with past date, allow keeping that date
      if (originalDate.isBefore(today)) {
        // Allow keeping the original past date, but not selecting new past dates
        firstDate = originalDate;
      } else {
        firstDate = today;
      }
    } else {
      // Allow past dates if setting allows
      firstDate = DateTime.now().subtract(const Duration(days: 365));
    }
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ar', 'SA'), // Arabic locale
      builder: (context, child) {
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        // Normalize date to start of day to avoid timezone issues
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LessonBloc, LessonState>(
      bloc: widget.lessonBloc,
      listener: (context, state) {
        if (state is LessonOperationSuccess) {
          Navigator.pop(context);
          widget.lessonBloc.add(LoadLessons(
            courseId: widget.courseId,
            year: _selectedDate.year,
            month: _selectedDate.month,
          ));
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
      child: AlertDialog(
        title: Text(AppLocalizations.of(context)!.editLesson),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Date field - clickable to open date picker
                  InkWell(
                    onTap: () => _selectDate(context),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.date,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.calendar_today),
                        suffixIcon: const Icon(Icons.arrow_drop_down),
                      ),
                      child: Text(
                        DateFormat('yyyy-MM-dd').format(_selectedDate),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Duration dropdown
                  DropdownButtonFormField<int>(
                    value: _selectedDuration,
                    decoration: InputDecoration(
                      labelText: 'المدة',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.access_time),
                    ),
                    items: _durationOptions.entries.map((entry) {
                      return DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedDuration = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'الرجاء اختيار المدة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Status dropdown: present, cancelled
                  DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.status,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.info),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'present',
                        child: const Text('حاضر'),
                      ),
                      DropdownMenuItem(
                        value: 'cancelled',
                        child: Text(AppLocalizations.of(context)!.cancelled),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _notesController,
                    label: AppLocalizations.of(context)!.notes,
                    prefixIcon: const Icon(Icons.note),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('إلغاء'),
          ),
          BlocBuilder<LessonBloc, LessonState>(
            bloc: widget.lessonBloc,
            builder: (context, state) {
              final isLoading = state is LessonLoading;
              return ElevatedButton(
                onPressed: isLoading ? null : () => _submitForm(context),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(AppLocalizations.of(context)!.updateLesson),
              );
            },
          ),
        ],
      ),
    );
  }

  void _submitForm(BuildContext context) {
    if (_formKey.currentState!.validate() && _selectedDuration != null) {
      final lesson = LessonModel(
        id: widget.lesson.id,
        courseId: widget.lesson.courseId,
        date: _selectedDate,
        duration: _selectedDuration!,
        status: _selectedStatus,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        duty: null, // Will be calculated automatically by backend
        createdBy: widget.lesson.createdBy,
        createdAt: widget.lesson.createdAt,
        updatedAt: DateTime.now(),
      );

      widget.lessonBloc.add(UpdateLesson(widget.lesson.id, lesson));
    }
  }
}

