import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/api_service.dart';
import '../../data/datasources/calendar_remote_datasource.dart';
import '../../data/repositories/calendar_repository_impl.dart';
import '../../domain/repositories/calendar_repository.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../widgets/modern_sidebar.dart';
import '../widgets/add_lesson_dialog.dart';
import 'calendar_day_view.dart';
import 'calendar_week_view.dart';

class CalendarHomePage extends StatefulWidget {
  const CalendarHomePage({super.key});

  @override
  State<CalendarHomePage> createState() => _CalendarHomePageState();
}

class _CalendarHomePageState extends State<CalendarHomePage>
    with SingleTickerProviderStateMixin {
  String currentView = 'day'; // day, week
  DateTime _selectedDate = DateTime.now();
  bool _isSidebarOpen = false;
  bool _isViewChanging = false;
  late AnimationController _animationController;
  late Animation<double> _sidebarAnimation;
  late Animation<double> _blurAnimation;

  // ── Session Management State ─────────────────────────────────────────────
  bool _isGeneratingSessions = false;
  bool _isClearingSessions = false;
  String? _lastSessionAction; // e.g. 'تم توليد 450 جلسة'
  DateTime? _lastGeneratedAt;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200), // Reduced from 300ms for faster animation
    );
    _sidebarAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic, // Changed to faster curve
    );
    // Remove blur animation - it's too expensive
    _blurAnimation = _sidebarAnimation; // Reuse sidebar animation

    // Load calendar events and teachers after first frame
    // Only load on first initialization, not when navigating back
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          final bloc = context.read<CalendarBloc>();
          final currentState = bloc.state;
          // Only load if we're in initial state and don't have cached data
          // This prevents double loading when navigating back
          if (currentState is CalendarInitial) {
            if (bloc.cachedEvents == null || bloc.cachedEvents!.isEmpty) {
              bloc.add(const LoadCalendarEvents());
            }
            if (bloc.cachedTeachers == null || bloc.cachedTeachers!.isEmpty) {
              bloc.add(const LoadCalendarTeachers());
            }
          }
        } catch (e) {
          // Handle error gracefully
          debugPrint('Error loading calendar data: $e');
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reset loading states when navigating back to this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isViewChanging = false;
        });
        // Only trigger load if bloc is in initial state and we don't have cached data
        // This prevents double loading when navigating back
        final bloc = context.read<CalendarBloc>();
        final currentState = bloc.state;
        if (currentState is CalendarInitial) {
          // Only load if we don't have cached data (to avoid double loading)
          if (bloc.cachedEvents == null || bloc.cachedEvents!.isEmpty) {
            bloc.add(const LoadCalendarEvents());
          }
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

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.path;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Main Content (always visible)
            Column(
              children: [
                // Header with view switcher
                _buildHeader(context),

                // Calendar View
                Expanded(
                  child: BlocConsumer<CalendarBloc, CalendarState>(
                    listener: (context, state) {
                      // Handle state changes if needed
                      if (state is CalendarError) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                    builder: (context, state) {
                      // If loading but we have cached events, show them instead
                      if (state is CalendarLoading) {
                        final bloc = context.read<CalendarBloc>();
                        if (bloc.cachedEvents != null) {
                          // Use cached events while loading
                          final cachedEvents = bloc.cachedEvents!;
                          Widget viewWidget;
                          if (currentView == 'day') {
                            viewWidget = CalendarDayView(
                              events: cachedEvents,
                              selectedDate: _selectedDate,
                              onDateChanged: (newDate) {
                                setState(() {
                                  _selectedDate = newDate;
                                });
                              },
                            );
                          } else if (currentView == 'week') {
                            viewWidget = CalendarWeekView(
                              events: cachedEvents,
                              selectedDate: _selectedDate,
                              onDateChanged: (newDate) {
                                setState(() {
                                  _selectedDate = newDate;
                                });
                              },
                            );
                          } else {
                            // Default to day view
                            viewWidget = CalendarDayView(
                              events: cachedEvents,
                              selectedDate: _selectedDate,
                              onDateChanged: (newDate) {
                                setState(() {
                                  _selectedDate = newDate;
                                });
                              },
                            );
                          }
                          return Stack(
                            children: [
                              viewWidget,
                              // Show subtle loading indicator
                              Positioned(
                                top: 10,
                                right: 10,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
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
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (state is CalendarError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSizes.spaceLg),
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
                                    context.read<CalendarBloc>().add(
                                          const LoadCalendarEvents(),
                                        );
                                  },
                                  child: const Text('إعادة المحاولة'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // Handle CalendarInitial state - show cached data if available, otherwise show loading
                      if (state is CalendarInitial) {
                        final bloc = context.read<CalendarBloc>();
                        // Check if we have cached events from a previous load
                        if (bloc.cachedEvents != null) {
                          // Show cached events while initializing
                          final cachedEvents = bloc.cachedEvents!;
                          Widget viewWidget;
                          if (currentView == 'day') {
                            viewWidget = CalendarDayView(
                              key: ValueKey('day-${_selectedDate.millisecondsSinceEpoch}'),
                              events: cachedEvents,
                              selectedDate: _selectedDate,
                              onDateChanged: (newDate) {
                                setState(() {
                                  _selectedDate = newDate;
                                });
                              },
                            );
                          } else if (currentView == 'week') {
                            viewWidget = CalendarWeekView(
                              key: ValueKey('week-${_selectedDate.millisecondsSinceEpoch}'),
                              events: cachedEvents,
                              selectedDate: _selectedDate,
                              onDateChanged: (newDate) {
                                setState(() {
                                  _selectedDate = newDate;
                                });
                              },
                            );
                          } else {
                            // Default to day view
                            viewWidget = CalendarDayView(
                              key: ValueKey('day-${_selectedDate.millisecondsSinceEpoch}'),
                              events: cachedEvents,
                              selectedDate: _selectedDate,
                              onDateChanged: (newDate) {
                                setState(() {
                                  _selectedDate = newDate;
                                });
                              },
                            );
                          }
                          return RepaintBoundary(child: viewWidget);
                        }
                        // No cached data - this is a fresh bloc, show loading
                        // The initState will trigger loading
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (state is CalendarEventsLoaded) {
                        // Show loading overlay when switching views
                        Widget viewWidget;
                        if (currentView == 'day') {
                          viewWidget = CalendarDayView(
                            key: ValueKey('day-${_selectedDate.millisecondsSinceEpoch}'),
                            events: state.events,
                            selectedDate: _selectedDate,
                            onDateChanged: (newDate) {
                              setState(() {
                                _selectedDate = newDate;
                              });
                            },
                          );
                        } else if (currentView == 'week') {
                          viewWidget = CalendarWeekView(
                            key: ValueKey('week-${_selectedDate.millisecondsSinceEpoch}'),
                            events: state.events,
                            selectedDate: _selectedDate,
                            onDateChanged: (newDate) {
                              setState(() {
                                _selectedDate = newDate;
                              });
                            },
                          );
                        } else {
                          // Default to day view
                          viewWidget = CalendarDayView(
                            key: ValueKey('day-${_selectedDate.millisecondsSinceEpoch}'),
                            events: state.events,
                            selectedDate: _selectedDate,
                            onDateChanged: (newDate) {
                              setState(() {
                                _selectedDate = newDate;
                              });
                            },
                          );
                        }
                        
                        return RepaintBoundary(
                          child: Stack(
                            children: [
                              viewWidget,
                              if (_isViewChanging)
                                Container(
                                  color: Colors.black.withOpacity(0.3),
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }

                      // Handle teachers loaded state - if we have events, show them
                      if (state is CalendarTeachersLoaded) {
                        final bloc = context.read<CalendarBloc>();
                        if (bloc.cachedEvents != null) {
                          // Show cached events
                          final cachedEvents = bloc.cachedEvents!;
                          Widget viewWidget;
                          if (currentView == 'day') {
                            viewWidget = CalendarDayView(
                              events: cachedEvents,
                              selectedDate: _selectedDate,
                              onDateChanged: (newDate) {
                                setState(() {
                                  _selectedDate = newDate;
                                });
                              },
                            );
                          } else if (currentView == 'week') {
                            viewWidget = CalendarWeekView(
                              events: cachedEvents,
                              selectedDate: _selectedDate,
                              onDateChanged: (newDate) {
                                setState(() {
                                  _selectedDate = newDate;
                                });
                              },
                            );
                          } else {
                            // Default to day view
                            viewWidget = CalendarDayView(
                              events: cachedEvents,
                              selectedDate: _selectedDate,
                              onDateChanged: (newDate) {
                                setState(() {
                                  _selectedDate = newDate;
                                });
                              },
                            );
                          }
                          return RepaintBoundary(child: viewWidget);
                        }
                        
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      // Handle initial state - show loading
                      if (state is CalendarInitial) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      // Handle operation success - reload events
                      if (state is CalendarOperationSuccess) {
                        // Trigger reload and show loading
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            context.read<CalendarBloc>().add(const LoadCalendarEvents());
                          }
                        });
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      // Default fallback - show loading (shouldn't reach here normally)
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    },
                  ),
                ),
              ],
            ),

            // Simplified overlay - remove expensive blur
            AnimatedBuilder(
              animation: _sidebarAnimation,
              builder: (context, child) {
                return Visibility(
                  visible: _isSidebarOpen,
                  child: GestureDetector(
                    onTap: _toggleSidebar,
                    child: Container(
                      color: Colors.black.withOpacity(0.3 * _sidebarAnimation.value),
                      // Remove BackdropFilter - it's too expensive
                    ),
                  ),
                );
              },
            ),

            // Sidebar overlay with RepaintBoundary - separate animation from content
            AnimatedBuilder(
              animation: _sidebarAnimation,
              builder: (context, child) {
                // child is the cached sidebar content that doesn't rebuild on animation
                return Positioned(
                  right: -280 * (1 - _sidebarAnimation.value),
                  top: 0,
                  bottom: 0,
                  width: 280,
                  child: child ?? const SizedBox.shrink(),
                );
              },
              child: RepaintBoundary(
                child: ModernSidebar(
                  currentRoute: currentRoute,
                  onClose: _toggleSidebar,
                ),
              ),
            ),

            // Floating toggle button - positioned to avoid header overlap
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: FloatingActionButton(
                mini: true,
                onPressed: _toggleSidebar,
                backgroundColor: AppColors.primary,
                child: Icon(
                  _isSidebarOpen ? Icons.close_rounded : Icons.menu_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSizes.spaceMd,
        right: 60, // Space for toggle button
        top: AppSizes.spaceSm,
        bottom: AppSizes.spaceSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Exit/Logout Button (Role-based)
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, authState) {
                final isCalendarManagerOnly = authState is AuthAuthenticated &&
                    authState.user.roles.contains('calendar_manager') &&
                    !authState.user.roles.contains('admin');

                return Container(
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: isCalendarManagerOnly
                        ? Colors.red.withOpacity(0.1)
                        : AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  ),
                  child: IconButton(
                    icon: Icon(
                      isCalendarManagerOnly ? Icons.logout_rounded : Icons.close_rounded,
                      size: 20,
                      color: isCalendarManagerOnly ? Colors.red : AppColors.primary,
                    ),
                    onPressed: () {
                      if (isCalendarManagerOnly) {
                        context.read<AuthBloc>().add(AuthLogoutRequested());
                        context.go('/login');
                      } else {
                        context.go('/management');
                      }
                    },
                    tooltip: isCalendarManagerOnly ? 'تسجيل الخروج' : 'العودة للوحة التحكم',
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: const EdgeInsets.all(6),
                  ),
                );
              },
            ),
            const SizedBox(width: AppSizes.spaceSm),
            // View Switcher - takes available space
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildViewButton('day', Icons.calendar_view_day_rounded),
                  ),
                  const SizedBox(width: AppSizes.spaceXs),
                  Expanded(
                    child: _buildViewButton('week', Icons.calendar_view_week_rounded),
                  ),
                ],
              ),
            ),

            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  onPressed: () {
                    context.read<CalendarBloc>().add(const LoadCalendarEvents());
                  },
                  tooltip: 'تحديث',
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: const EdgeInsets.all(6),
                ),
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        // Read CalendarBloc from the original context before showing dialog
                        final calendarBloc = context.read<CalendarBloc>();
                        
                        showDialog(
                          context: context,
                          builder: (dialogContext) => BlocProvider<CalendarBloc>.value(
                            value: calendarBloc,
                            child: const AddLessonDialog(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewButton(String view, IconData icon) {
    final isActive = currentView == view;
    return InkWell(
      onTap: () {
        if (currentView != view && !_isViewChanging) {
          setState(() {
            _isViewChanging = true;
          });
          // Add a small delay to show loading, then switch view
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              setState(() {
                currentView = view;
                _isViewChanging = false;
              });
            }
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spaceXs,
          vertical: AppSizes.spaceXs,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          border: isActive
              ? Border.all(color: AppColors.primary, width: 1)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 2),
            Text(
              view == 'week' ? 'أسبوعي' : 'يومي',
              style: TextStyle(
                fontSize: 10,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── Session Management Card (Admin Only) ──────────────────────────────────
  Widget _buildSessionManagementCard(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final isAdmin = authState is AuthAuthenticated &&
            authState.user.roles.contains('admin');
        if (!isAdmin) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.fromLTRB(AppSizes.spaceMd, 0, AppSizes.spaceMd, AppSizes.spaceSm),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.calendar_month_rounded,
                          size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: AppSizes.spaceSm),
                    const Text(
                      'إدارة الجلسات',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_lastGeneratedAt != null) ...[                      
                      const Spacer(),
                      Text(
                        'آخر توليد: ${_lastGeneratedAt!.hour.toString().padLeft(2,'0')}:${_lastGeneratedAt!.minute.toString().padLeft(2,'0')}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ]
                  ],
                ),

                // Status message
                if (_lastSessionAction != null) ...[                  
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded,
                            size: 14, color: Colors.green),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _lastSessionAction!,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: AppSizes.spaceSm),

                // Buttons row
                Row(
                  children: [
                    // Generate button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (_isGeneratingSessions || _isClearingSessions)
                            ? null
                            : () => _generateSessions(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                          ),
                        ),
                        icon: _isGeneratingSessions
                            ? const SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(
                          _isGeneratingSessions ? 'جاري التوليد...' : 'توليد الجلسات (3 أشهر)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.spaceSm),
                    // Clear button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (_isGeneratingSessions || _isClearingSessions)
                            ? null
                            : () => _confirmClearSessions(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                        icon: _isClearingSessions
                            ? const SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.red),
                              )
                            : const Icon(Icons.delete_sweep_rounded, size: 16),
                        label: Text(
                          _isClearingSessions ? 'جاري الحذف...' : 'حذف جميع الجلسات',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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

  Future<void> _generateSessions(BuildContext context) async {
    setState(() {
      _isGeneratingSessions = true;
      _lastSessionAction = null;
    });
    try {
      final apiService = context.read<ApiService>();
      final response = await apiService.post('/v1/calendar/sessions/generate');
      final data = response.data as Map<String, dynamic>;
      final created = data['sessions_created'] ?? 0;
      final total = data['total_sessions'] ?? 0;
      if (mounted) {
        setState(() {
          _lastSessionAction = 'تم توليد $created جلسة جديدة — الإجمالي: $total';
          _lastGeneratedAt = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل توليد الجلسات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingSessions = false);
    }
  }

  Future<void> _confirmClearSessions(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف', textAlign: TextAlign.right),
        content: const Text(
          'هل أنت متأكد من حذف جميع الجلسات القادمة والتذكيرات المعلقة؟\nلا يمكن التراجع عن هذا الإجراء.',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف الكل', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isClearingSessions = true;
      _lastSessionAction = null;
    });
    try {
      final apiService = context.read<ApiService>();
      final response = await apiService.delete('/v1/calendar/sessions/clear-all');
      final data = response.data as Map<String, dynamic>;
      final deleted = data['deleted_sessions'] ?? 0;
      final deletedReminders = data['deleted_reminders'] ?? 0;
      if (mounted) {
        setState(() {
          _lastSessionAction = 'تم حذف $deleted جلسة و $deletedReminders تذكير';
          _lastGeneratedAt = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل حذف الجلسات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isClearingSessions = false);
    }
  }

  // Removed _getTeachersFromState() - now using BlocBuilder with caching
}
