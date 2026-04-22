import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import 'exceptional_class_page.dart';
import 'student_info_page.dart';

class TeacherStudentsPage extends StatefulWidget {
  final int teacherId;
  final String teacherName;

  const TeacherStudentsPage({
    super.key,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  State<TeacherStudentsPage> createState() => _TeacherStudentsPageState();
}

class _TeacherStudentsPageState extends State<TeacherStudentsPage> {
  bool _hasTriggeredLoad = false; // Track if we've triggered a load

  @override
  void initState() {
    super.initState();
    // Load students only if not already cached
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final bloc = context.read<CalendarBloc>();
        final cachedStudents = bloc.getCachedStudents(widget.teacherId);
        final currentState = bloc.state;
        
        // Only load if state is initial or if students are not cached
        if (currentState is CalendarInitial || 
            (currentState is! CalendarTeacherStudentsLoaded && (cachedStudents == null || cachedStudents.isEmpty))) {
          bloc.add(LoadTeacherStudents(widget.teacherId));
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ensure students are loaded when navigating back to this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final bloc = context.read<CalendarBloc>();
        final currentState = bloc.state;
        final cachedStudents = bloc.getCachedStudents(widget.teacherId);
        
        // Handle other states (happens when coming back from nested pages)
        if (currentState is! CalendarTeacherStudentsLoaded && currentState is! CalendarLoading) {
          // If we don't have cached students, load them immediately
          if (cachedStudents == null || cachedStudents.isEmpty) {
            // Reset flag and trigger load
            _hasTriggeredLoad = false;
            bloc.add(LoadTeacherStudents(widget.teacherId));
          } else {
            // Reset flag when we have cached data
            _hasTriggeredLoad = false;
          }
          return;
        }
        
        // Only trigger load if bloc is in initial state and we don't have cached data
        // This prevents double loading when navigating back
        if (currentState is CalendarInitial) {
          // Only load if we don't have cached data (to avoid double loading)
          if (cachedStudents == null || cachedStudents.isEmpty) {
            bloc.add(LoadTeacherStudents(widget.teacherId));
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        // Reset the flag when back button is pressed
        // This ensures we can trigger load again when page becomes visible
        if (didPop) {
          _hasTriggeredLoad = false;
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('طلاب ${widget.teacherName}'),
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
              context.read<CalendarBloc>().add(LoadTeacherStudents(widget.teacherId));
            } else if (state is CalendarError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
              // Reset the flag on error so we can retry
              _hasTriggeredLoad = false;
            } else if (state is CalendarTeacherStudentsLoaded) {
              // Reset the flag when students are successfully loaded
              _hasTriggeredLoad = false;
            }
          },
          builder: (context, state) {
            final bloc = context.read<CalendarBloc>();
            
            // Always check for cached students first, regardless of state
            final cachedStudents = bloc.getCachedStudents(widget.teacherId);
            if (cachedStudents != null && cachedStudents.isNotEmpty) {
              // If loading, show cached with indicator
              if (state is CalendarLoading) {
                return Stack(
                  children: [
                    _buildStudentsList(cachedStudents),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  ],
                );
              }
              // If initial or other state, show cached immediately
              if (state is CalendarInitial || state is! CalendarTeacherStudentsLoaded) {
                return _buildStudentsList(cachedStudents);
              }
            }
            
            // If loading but no cache, show loading
            if (state is CalendarLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            
            // If state is initial and no cache, show loading (load is triggered in initState)
            if (state is CalendarInitial) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is CalendarTeacherStudentsLoaded) {
              final students = state.students;

              if (students.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline_rounded,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: AppSizes.spaceMd),
                      Text(
                        'لا يوجد طلاب',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return _buildStudentsList(students);
            }

            if (state is CalendarError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppColors.accentOrange,
                    ),
                    const SizedBox(height: AppSizes.spaceMd),
                    Text(
                      state.message,
                      style: const TextStyle(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSizes.spaceMd),
                    ElevatedButton(
                      onPressed: () {
                        context.read<CalendarBloc>().add(LoadTeacherStudents(widget.teacherId));
                      },
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              );
            }

            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }

  Widget _buildStudentsList(List<Map<String, dynamic>> students) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSizes.spaceMd),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        return Card(
          margin: const EdgeInsets.only(bottom: AppSizes.spaceMd),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Student Name
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSizes.spaceMd),
                    Expanded(
                      child: Text(
                        student['student_name'] ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spaceSm),
                // Country and Status
                Row(
                  children: [
                    Icon(
                      Icons.public_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'البلد: ${student['country'] ?? ''}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: AppSizes.spaceMd),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (student['status'] == 'active'
                                ? Colors.green
                                : Colors.red)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        student['status'] == 'active' ? 'نشط' : 'غير نشط',
                        style: TextStyle(
                          color: student['status'] == 'active'
                              ? Colors.green
                              : Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spaceMd),
                const Divider(),
                const SizedBox(height: AppSizes.spaceSm),
                // Action Buttons
                Wrap(
                  spacing: AppSizes.spaceXs,
                  runSpacing: AppSizes.spaceXs,
                  children: [
                    // Exceptional Button
                    ElevatedButton.icon(
                      onPressed: () {
                        final bloc = context.read<CalendarBloc>();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (newContext) => BlocProvider.value(
                              value: bloc,
                              child: ExceptionalClassPage(
                                studentName: student['student_name'] ?? '',
                                teacherId: widget.teacherId,
                                teacherName: widget.teacherName,
                              ),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.event_note_rounded, size: 18),
                      label: const Text('حصة استثنائية'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        minimumSize: const Size(0, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    // Info Button
                    OutlinedButton.icon(
                      onPressed: () {
                        final bloc = context.read<CalendarBloc>();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (newContext) => BlocProvider.value(
                              value: bloc,
                              child: StudentInfoPage(
                                studentName: student['student_name'] ?? '',
                                currentStatus: student['status'] ?? 'active',
                                reactiveDate: student['reactive_date'],
                              ),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.info_rounded, size: 18),
                      label: const Text('معلومات'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        minimumSize: const Size(0, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
