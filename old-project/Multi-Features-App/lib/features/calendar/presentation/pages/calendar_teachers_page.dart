import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../widgets/modern_sidebar.dart';
import '../../data/models/calendar_teacher_model.dart';
import '../../data/repositories/calendar_repository_impl.dart';
import '../../data/datasources/calendar_remote_datasource.dart';
import '../../../../core/utils/api_service.dart';
import 'teacher_timetable_page.dart';
import 'teacher_students_page.dart';

class CalendarTeachersPage extends StatefulWidget {
  const CalendarTeachersPage({super.key});

  @override
  State<CalendarTeachersPage> createState() => _CalendarTeachersPageState();
}

class _CalendarTeachersPageState extends State<CalendarTeachersPage>
    with SingleTickerProviderStateMixin {
  bool _isSidebarOpen = false;
  late AnimationController _animationController;
  late Animation<double> _sidebarAnimation;
  late Animation<double> _blurAnimation;
  final Set<int> _loadingTeacherIds = {}; // Track which teachers are loading WhatsApp
  bool _hasTriggeredLoad = false; // Track if we've triggered a load for CalendarEventsLoaded state
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _sidebarAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _blurAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Load teachers only if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final bloc = context.read<CalendarBloc>();
        final currentState = bloc.state;
        // Only load if state is initial or if teachers are not cached
        if (currentState is CalendarInitial || 
            (currentState is! CalendarTeachersLoaded && (bloc.cachedTeachers == null || bloc.cachedTeachers!.isEmpty))) {
          bloc.add(const LoadCalendarTeachers());
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ensure teachers are loaded when navigating back to this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final bloc = context.read<CalendarBloc>();
        final currentState = bloc.state;
        
        // Handle CalendarEventsLoaded state (happens when coming back from timetable page)
        if (currentState is CalendarEventsLoaded) {
          // If we don't have cached teachers, load them immediately
          if (bloc.cachedTeachers == null || bloc.cachedTeachers!.isEmpty) {
            // Reset flag and trigger load
            _hasTriggeredLoad = false;
            bloc.add(const LoadCalendarTeachers());
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
          if (bloc.cachedTeachers == null || bloc.cachedTeachers!.isEmpty) {
            bloc.add(const LoadCalendarTeachers());
          }
        }
      }
    });
  }


  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
      if (_isSidebarOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _showAddTeacherDialog() {
    final nameController = TextEditingController();
    final whatsappController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    // Get the bloc before showing the dialog to ensure we have access to it
    final calendarBloc = context.read<CalendarBloc>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة معلم'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المعلم',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال اسم المعلم';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSizes.spaceMd),
              TextFormField(
                controller: whatsappController,
                decoration: const InputDecoration(
                  labelText: 'رقم الواتساب',
                  border: OutlineInputBorder(),
                ),
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال رقم الواتساب';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                calendarBloc.add(
                      CreateCalendarTeacher(
                        CalendarTeacherModel(
                          id: 0,
                          name: nameController.text,
                          whatsappNumber: whatsappController.text,
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        ),
                      ),
                    );
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showEditTeacherDialog(CalendarTeacherModel teacher) {
    final nameController = TextEditingController(text: teacher.name);
    final whatsappController = TextEditingController(text: teacher.whatsappNumber);
    final formKey = GlobalKey<FormState>();
    
    // Capture the bloc before showing the dialog
    final bloc = context.read<CalendarBloc>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تعديل معلم'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المعلم',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال اسم المعلم';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSizes.spaceMd),
              TextFormField(
                controller: whatsappController,
                decoration: const InputDecoration(
                  labelText: 'رقم الواتساب',
                  border: OutlineInputBorder(),
                ),
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال رقم الواتساب';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                bloc.add(
                      UpdateCalendarTeacher(
                        teacher.id,
                        teacher.copyWith(
                          name: nameController.text,
                          whatsappNumber: whatsappController.text,
                        ),
                      ),
                    );
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(CalendarTeacherModel teacher) {
    // Capture the bloc before showing the dialog
    final bloc = context.read<CalendarBloc>();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف ${teacher.name}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              bloc.add(DeleteCalendarTeacher(teacher.id));
              Navigator.of(dialogContext).pop();
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

  String _formatPhoneNumber(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      return '';
    }
    
    // Remove all non-digit characters
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // Remove leading zeros
    while (cleaned.isNotEmpty && cleaned[0] == '0') {
      cleaned = cleaned.substring(1);
    }
    
    // If it starts with country code, keep it; otherwise add it
    if (cleaned.startsWith('20')) {
      return cleaned;
    } else if (cleaned.isNotEmpty) {
      return '20$cleaned';
    }
    
    return '';
  }

  Future<void> _sendTeacherTimetableToWhatsApp(int teacherId, String? phoneNumber) async {
    try {
      setState(() {
        _loadingTeacherIds.add(teacherId);
      });

      // Create repository instance to call the API
      final apiService = ApiService();
      final remoteDataSource = CalendarRemoteDataSourceImpl(apiService);
      final repository = CalendarRepositoryImpl(remoteDataSource);
      
      // Get the WhatsApp message and phone number from API
      final result = await repository.getTeacherTimetableWhatsApp(teacherId);
      final message = result['report'] as String? ?? '';
      final apiPhoneNumber = result['phoneNumber'] as String? ?? phoneNumber;
      
      // Use API phone number if available, otherwise use provided phone number
      final finalPhoneNumber = apiPhoneNumber ?? phoneNumber;
      
      if (finalPhoneNumber == null || finalPhoneNumber.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يوجد رقم واتساب للمعلم'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Format phone number
      final formattedPhone = _formatPhoneNumber(finalPhoneNumber);
      if (formattedPhone.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('رقم واتساب غير صحيح'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Build WhatsApp URL - message is already URL-encoded from backend
      // Construct URL manually to avoid double encoding
      final whatsappUrl = Uri.parse('https://wa.me/$formattedPhone?text=$message');
      
      // Try to launch WhatsApp
      bool launched = false;
      
      // First try: external non-browser application (preferred for Android)
      try {
        launched = await launchUrl(
          whatsappUrl,
          mode: LaunchMode.externalNonBrowserApplication,
        );
      } catch (e) {
        // If that fails, try external application
        try {
          launched = await launchUrl(
            whatsappUrl,
            mode: LaunchMode.externalApplication,
          );
        } catch (e2) {
          // Last resort: platform default
          launched = await launchUrl(
            whatsappUrl,
            mode: LaunchMode.platformDefault,
          );
        }
      }
      
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح واتساب. تأكد من تثبيت التطبيق'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في فتح واتساب: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingTeacherIds.remove(teacherId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = '/calendar/teachers';

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
      body: SafeArea(
        child: Stack(
          children: [
            // Main Content
            Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(AppSizes.spaceMd),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.textTertiary.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu_rounded),
                        onPressed: _toggleSidebar,
                        color: AppColors.primary,
                      ),
                      const Expanded(
                        child: Text(
                          'المعلمون',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_rounded),
                        onPressed: _showAddTeacherDialog,
                        color: AppColors.primary,
                        tooltip: 'إضافة معلم',
                      ),
                    ],
                  ),
                ),
                // Search Field
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.spaceMd,
                    vertical: AppSizes.spaceSm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.textTertiary.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      hintText: 'ابحث عن معلم...',
                      hintTextDirection: TextDirection.rtl,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.spaceMd,
                        vertical: AppSizes.spaceSm,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                ),
                // Content
                Expanded(
                  child: BlocConsumer<CalendarBloc, CalendarState>(
                    listener: (context, state) {
                      if (state is CalendarOperationSuccess) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تمت العملية بنجاح'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        context.read<CalendarBloc>().add(const LoadCalendarTeachers());
                      } else if (state is CalendarError) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            backgroundColor: Colors.red,
                          ),
                        );
                        // Reset the flag on error so we can retry
                        _hasTriggeredLoad = false;
                      } else if (state is CalendarTeachersLoaded) {
                        // Reset the flag when teachers are successfully loaded
                        _hasTriggeredLoad = false;
                      }
                    },
                    builder: (context, state) {
                      final bloc = context.read<CalendarBloc>();
                      
                      // Get search query
                      final searchQuery = _searchController.text.toLowerCase().trim();
                      
                      // Filter function
                      List<CalendarTeacherModel> filterTeachers(List<CalendarTeacherModel> teachers) {
                        if (searchQuery.isEmpty) {
                          return teachers;
                        }
                        return teachers.where((teacher) {
                          return teacher.name.toLowerCase().contains(searchQuery) ||
                                 teacher.whatsappNumber.contains(searchQuery);
                        }).toList();
                      }
                      
                      // Always check for cached teachers first, regardless of state
                      if (bloc.cachedTeachers != null && bloc.cachedTeachers!.isNotEmpty) {
                        final filteredCachedTeachers = filterTeachers(bloc.cachedTeachers!);
                        
                        // If loading, show cached with indicator
                        if (state is CalendarLoading) {
                          return Stack(
                            children: [
                              _buildTeachersList(filteredCachedTeachers),
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
                        if (state is CalendarInitial || state is! CalendarTeachersLoaded) {
                          return _buildTeachersList(filteredCachedTeachers);
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

                      // Handle CalendarEventsLoaded state (might happen when coming from timetable page)
                      if (state is CalendarEventsLoaded) {
                        // If we have cached teachers, show them immediately
                        if (bloc.cachedTeachers != null && bloc.cachedTeachers!.isNotEmpty) {
                          _hasTriggeredLoad = false; // Reset flag when showing cached data
                          final filteredCachedTeachers = filterTeachers(bloc.cachedTeachers!);
                          return _buildTeachersList(filteredCachedTeachers);
                        }
                        // Otherwise trigger load in post-frame callback to avoid calling add during build
                        // Always trigger if we haven't triggered yet or if flag was reset
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && !_hasTriggeredLoad) {
                            _hasTriggeredLoad = true;
                            bloc.add(const LoadCalendarTeachers());
                          }
                        });
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (state is CalendarTeachersLoaded) {
                        final teachers = state.teachers;
                        final filteredTeachers = filterTeachers(teachers);
                        
                        if (filteredTeachers.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  searchQuery.isNotEmpty
                                      ? Icons.search_off_rounded
                                      : Icons.people_outline_rounded,
                                  size: 64,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(height: AppSizes.spaceMd),
                                Text(
                                  searchQuery.isNotEmpty
                                      ? 'لا توجد نتائج للبحث'
                                      : 'لا يوجد معلمون',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return _buildTeachersList(filteredTeachers);
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
                                  context.read<CalendarBloc>().add(const LoadCalendarTeachers());
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
              ],
            ),

            // Blur overlay when sidebar is open
            AnimatedBuilder(
              animation: _blurAnimation,
              builder: (context, child) {
                return Visibility(
                  visible: _isSidebarOpen,
                  child: GestureDetector(
                    onTap: _toggleSidebar,
                    child: Container(
                      color: Colors.black.withOpacity(0.3 * _blurAnimation.value),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 5.0 * _blurAnimation.value,
                          sigmaY: 5.0 * _blurAnimation.value,
                        ),
                        child: Container(
                          color: Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Sidebar overlay
            AnimatedBuilder(
              animation: _sidebarAnimation,
              builder: (context, child) {
                return Positioned(
                  right: -280 * (1 - _sidebarAnimation.value),
                  top: 0,
                  bottom: 0,
                  child: ModernSidebar(
                    currentRoute: currentRoute,
                    onClose: _toggleSidebar,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildTeachersList(List<CalendarTeacherModel> teachers) {
    return ListView.builder(
                          padding: const EdgeInsets.all(AppSizes.spaceMd),
                          itemCount: teachers.length,
                          itemBuilder: (context, index) {
                            final teacher = teachers[index];
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
                                    // Teacher Name Header
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
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                teacher.name,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.phone_rounded,
                                                    size: 16,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    teacher.whatsappNumber,
                                                    style: TextStyle(
                                                      color: AppColors.textSecondary,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (teacher.timetablesCount != null) ...[
                                      const SizedBox(height: AppSizes.spaceSm),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.people_rounded,
                                            size: 16,
                                            color: AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'عدد الطلاب: ${teacher.timetablesCount}',
                                            style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: AppSizes.spaceMd),
                                    const Divider(),
                                    const SizedBox(height: AppSizes.spaceSm),
                                    // Action Buttons
                                    Wrap(
                                      spacing: AppSizes.spaceXs,
                                      runSpacing: AppSizes.spaceXs,
                                      children: [
                                        // Timetable Button
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            final bloc = context.read<CalendarBloc>();
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (newContext) => BlocProvider.value(
                                                  value: bloc,
                                                  child: TeacherTimetablePage(teacherId: teacher.id, teacherName: teacher.name),
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.schedule_rounded, size: 18),
                                          label: const Text('الجداول'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            minimumSize: const Size(0, 40),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                        // WhatsApp Button
                                        ElevatedButton.icon(
                                          onPressed: _loadingTeacherIds.contains(teacher.id) 
                                              ? null 
                                              : () => _sendTeacherTimetableToWhatsApp(
                                                    teacher.id,
                                                    teacher.whatsappNumber,
                                                  ),
                                          icon: _loadingTeacherIds.contains(teacher.id)
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                  ),
                                                )
                                              : const Icon(Icons.chat_rounded, size: 18),
                                          label: const Text('واتساب'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            minimumSize: const Size(0, 40),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                        // Edit Button
                                        OutlinedButton.icon(
                                          onPressed: () => _showEditTeacherDialog(teacher),
                                          icon: const Icon(Icons.edit_rounded, size: 18),
                                          label: const Text('تعديل'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.primary,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            minimumSize: const Size(0, 40),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                        // Students Button
                                        OutlinedButton.icon(
                                          onPressed: () {
                                            final bloc = context.read<CalendarBloc>();
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (newContext) => BlocProvider.value(
                                                  value: bloc,
                                                  child: TeacherStudentsPage(
                                                    teacherId: teacher.id,
                                                    teacherName: teacher.name,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.people_rounded, size: 18),
                                          label: const Text('الطلاب'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.blue,
                                            side: const BorderSide(color: Colors.blue),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            minimumSize: const Size(0, 40),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                        // Delete Button
                                        OutlinedButton.icon(
                                          onPressed: () => _showDeleteConfirmation(teacher),
                                          icon: const Icon(Icons.delete_rounded, size: 18),
                                          label: const Text('حذف'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.red,
                                            side: const BorderSide(color: Colors.red),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
