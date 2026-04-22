import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../core/models/user_role.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/meetings/presentation/pages/meetings_page.dart';
import '../../features/users_courses/presentation/pages/users_courses_home_page.dart';
import '../../features/billing/presentation/pages/billing_and_reports_home_page.dart';
import '../../features/billing/presentation/pages/auto_billings_page.dart';
import '../../features/billing/presentation/pages/manual_billings_page.dart';
import '../../features/billing/presentation/pages/manual_billing_form_page.dart';
import '../../features/billing/presentation/pages/billing_details_page.dart';
import '../../features/billing/presentation/pages/billing_send_logs_page.dart';
import '../../features/billing/data/models/auto_billing_model.dart';
import '../../features/billing/data/models/manual_billing_model.dart';
import '../../features/certificates/presentation/pages/certificates_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/students/presentation/pages/students_list_page.dart';
import '../../features/students/presentation/pages/student_form_page.dart';
import '../../features/teachers/presentation/pages/teachers_list_page.dart';
import '../../features/teachers/presentation/pages/teacher_form_page.dart';
import '../../features/teachers/presentation/pages/teacher_panel_page.dart';
import '../../features/teachers/presentation/pages/teacher_calendar_page.dart';
import '../../features/teachers/presentation/pages/admin_teacher_courses_page.dart';
import '../../features/courses/presentation/pages/courses_list_page.dart';
import '../../features/courses/presentation/pages/course_form_page.dart';
import '../../features/lessons/presentation/pages/lessons_list_page.dart';
import '../../features/lessons/presentation/pages/lesson_form_page.dart';
import '../../features/salaries/presentation/pages/salaries_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/teachers/data/models/teacher_model.dart';
import '../../features/timetables/presentation/pages/timetable_webview_page.dart';
import '../../features/calendar/presentation/pages/calendar_home_page.dart';
import '../../features/calendar/presentation/pages/reminders_page.dart';
import '../../features/calendar/presentation/pages/student_stops_page.dart';
import '../../features/calendar/presentation/pages/exceptional_classes_page.dart';
import '../../features/calendar/presentation/pages/calendar_teachers_page.dart';
import '../../features/calendar/presentation/pages/teacher_timetable_page.dart';
import '../../features/calendar/data/datasources/calendar_remote_datasource.dart';
import '../../features/student_countries/presentation/pages/student_countries_page.dart';
import '../../features/student_countries/data/datasources/student_countries_remote_datasource.dart';
import '../../features/student_countries/presentation/bloc/student_countries_bloc.dart';
import '../../features/calendar/data/repositories/calendar_repository_impl.dart';
import '../../features/calendar/domain/repositories/calendar_repository.dart';
import '../../features/calendar/presentation/bloc/calendar_bloc.dart';
import '../../core/utils/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../features/client_panel/presentation/pages/client_dashboard_page.dart';
import '../../features/client_panel/presentation/pages/rooms_management_page.dart';
import '../../features/client_panel/presentation/pages/subscription_page.dart';
import '../../features/client_panel/presentation/pages/client_settings_page.dart';

/// Application router configuration using GoRouter
class AppRouter {
  AppRouter._();

  // Route names
  static const String login = '/';
  static const String dashboard = '/dashboard';
  static const String rooms = '/rooms';
  static const String usersAndCourses = '/users-courses';
  static const String billings = '/billings';
  static const String calendar = '/calendar';
  static const String certificates = '/certificates';
  static const String settings = '/settings';
  static const String students = '/students';
  static const String teachers = '/teachers';
  static const String teacherPanel = '/teacher-panel';
  static const String teacherCalendar = '/teacher-calendar';
  static const String courses = '/courses';
  static const String lessons = '/lessons';
  static const String salaries = '/salaries';
  static const String reports = '/reports';
  static const String timetables = '/timetables';
  static const String studentCountries = '/student-countries';

  static GoRouter router = GoRouter(
    initialLocation: login,
    redirect: (context, state) {
      // Get auth state from context if available
      try {
        final authBloc = context.read<AuthBloc>();
        final authState = authBloc.state;
        
        final isLoginPage = state.uri.path == login;
        
        // If authenticated and on login page, redirect to appropriate dashboard
        if (authState is Authenticated) {
          if (isLoginPage) {
            return authState.user.role == UserRole.teacher 
                ? teacherPanel 
                : dashboard;
          }
          // Allow access to other pages if authenticated
          return null;
        }
        
        // If not authenticated and not on login page, redirect to login
        if (authState is Unauthenticated && !isLoginPage) {
          return login;
        }
        
        // If still loading or initial, allow navigation (will be handled by listener)
        return null;
      } catch (e) {
        // If context doesn't have AuthBloc yet, allow navigation
        return null;
      }
    },
    routes: [
      GoRoute(
        path: login,
        name: 'login',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const LoginPage(),
        ),
      ),
      GoRoute(
        path: dashboard,
        name: 'dashboard',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const DashboardPage(),
        ),
      ),
      GoRoute(
        path: rooms,
        name: 'rooms',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const MeetingsPage(),
        ),
      ),
      GoRoute(
        path: calendar,
        name: 'calendar',
        pageBuilder: (context, state) {
          // Setup CalendarBloc dependencies
          final apiService = ApiService();
          // Load and set auth token if available (calendar routes are public but token helps if user is logged in)
          StorageService.getToken().then((token) {
            if (token != null) {
              apiService.setAuthToken(token);
            }
          });
          final remoteDataSource = CalendarRemoteDataSourceImpl(apiService);
          final repository = CalendarRepositoryImpl(remoteDataSource);
          final calendarBloc = CalendarBloc(repository);
          
          return _buildPageWithTransition(
            context: context,
            state: state,
            child: BlocProvider<CalendarBloc>.value(
              value: calendarBloc,
              child: const CalendarHomePage(),
            ),
          );
        },
        routes: [
          GoRoute(
            path: 'reminders',
            name: 'calendar-reminders',
            pageBuilder: (context, state) {
              // Setup CalendarBloc dependencies
              final apiService = ApiService();
              final remoteDataSource = CalendarRemoteDataSourceImpl(apiService);
              final repository = CalendarRepositoryImpl(remoteDataSource);
              final calendarBloc = CalendarBloc(repository);
              
              return _buildPageWithTransition(
                context: context,
                state: state,
                child: BlocProvider<CalendarBloc>.value(
                  value: calendarBloc,
                  child: const RemindersPage(),
                ),
              );
            },
          ),
          GoRoute(
            path: 'student-stops',
            name: 'calendar-student-stops',
            pageBuilder: (context, state) {
              final apiService = ApiService();
              final remoteDataSource = CalendarRemoteDataSourceImpl(apiService);
              final repository = CalendarRepositoryImpl(remoteDataSource);
              final calendarBloc = CalendarBloc(repository);
              
              return _buildPageWithTransition(
                context: context,
                state: state,
                child: BlocProvider<CalendarBloc>.value(
                  value: calendarBloc,
                  child: const StudentStopsPage(),
                ),
              );
            },
          ),
          GoRoute(
            path: 'exceptional-classes',
            name: 'calendar-exceptional-classes',
            pageBuilder: (context, state) {
              final apiService = ApiService();
              final remoteDataSource = CalendarRemoteDataSourceImpl(apiService);
              final repository = CalendarRepositoryImpl(remoteDataSource);
              final calendarBloc = CalendarBloc(repository);
              
              return _buildPageWithTransition(
                context: context,
                state: state,
                child: BlocProvider<CalendarBloc>.value(
                  value: calendarBloc,
                  child: const ExceptionalClassesPage(),
                ),
              );
            },
          ),
          GoRoute(
            path: 'teachers',
            name: 'calendar-teachers',
            pageBuilder: (context, state) {
              final apiService = ApiService();
              final remoteDataSource = CalendarRemoteDataSourceImpl(apiService);
              final repository = CalendarRepositoryImpl(remoteDataSource);
              final calendarBloc = CalendarBloc(repository);
              
              return _buildPageWithTransition(
                context: context,
                state: state,
                child: BlocProvider<CalendarBloc>.value(
                  value: calendarBloc,
                  child: const CalendarTeachersPage(),
                ),
              );
            },
          ),
          GoRoute(
            path: 'student-countries',
            name: 'calendar-student-countries',
            pageBuilder: (context, state) => _buildPageWithTransition(
              context: context,
              state: state,
              child: const StudentCountriesPage(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: timetables,
        name: 'timetables',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const TimetableWebViewPage(),
        ),
      ),
      GoRoute(
        path: usersAndCourses,
        name: 'users-courses',
        builder: (context, state) => const UsersCoursesHomePage(),
        routes: [
          // Students routes
          GoRoute(
            path: 'students',
            name: 'students',
            builder: (context, state) => const UsersCoursesHomePage(),
            routes: [
              GoRoute(
                path: 'create',
                name: 'students-create',
                pageBuilder: (context, state) => _buildPageWithTransition(
                  context: context,
                  state: state,
                  child: const StudentFormPage(),
                ),
              ),
              GoRoute(
                path: ':id',
                name: 'student-detail',
                builder: (context, state) => const UsersCoursesHomePage(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'student-edit',
                    pageBuilder: (context, state) {
                      final studentId =
                          int.tryParse(state.pathParameters['id'] ?? '');
                      return _buildPageWithTransition(
                        context: context,
                        state: state,
                        child: StudentFormPage(studentId: studentId),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          // Teachers routes
          GoRoute(
            path: 'teachers',
            name: 'teachers',
            builder: (context, state) => const UsersCoursesHomePage(),
            routes: [
              GoRoute(
                path: 'create',
                name: 'teachers-create',
                pageBuilder: (context, state) => _buildPageWithTransition(
                  context: context,
                  state: state,
                  child: const TeacherFormPage(),
                ),
              ),
              GoRoute(
                path: ':id',
                name: 'teacher-detail',
                builder: (context, state) => const UsersCoursesHomePage(),
                routes: [
                  GoRoute(
                    path: 'courses',
                    name: 'teacher-courses',
                    pageBuilder: (context, state) {
                      final teacherId =
                          int.tryParse(state.pathParameters['id'] ?? '');
                      if (teacherId == null) {
                        // If teacherId is invalid, show error page or navigate back
                        return _buildPageWithTransition(
                          context: context,
                          state: state,
                          child: Scaffold(
                            appBar: AppBar(title: const Text('خطأ')),
                            body: const Material(
                              child: Center(
                                child: Text('معرف المعلم غير صحيح'),
                              ),
                            ),
                          ),
                        );
                      }
                      return _buildPageWithTransition(
                        context: context,
                        state: state,
                        child: AdminTeacherCoursesPage(teacherId: teacherId),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'edit',
                    name: 'teacher-edit',
                    pageBuilder: (context, state) {
                      final teacher = state.extra is TeacherModel
                          ? state.extra as TeacherModel
                          : null;
                      final teacherId =
                          int.tryParse(state.pathParameters['id'] ?? '');
                      return _buildPageWithTransition(
                        context: context,
                        state: state,
                        child: TeacherFormPage(
                          teacherId: teacherId,
                          teacher: teacher,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          // Salaries route
          GoRoute(
            path: 'salaries',
            name: 'salaries',
            builder: (context, state) => const UsersCoursesHomePage(),
          ),
          // Reports route
          GoRoute(
            path: 'reports',
            name: 'reports',
            builder: (context, state) => const UsersCoursesHomePage(),
          ),
        ],
      ),
      GoRoute(
        path: billings,
        name: 'billings',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const BillingAndReportsHomePage(),
        ),
        routes: [
          GoRoute(
            path: 'auto',
            name: 'auto-billings',
            builder: (context, state) => const BillingAndReportsHomePage(),
            routes: [
              GoRoute(
                path: 'send-logs',
                name: 'billing-send-logs',
                pageBuilder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  final year = extra?['year'] as int? ?? DateTime.now().year;
                  final month = extra?['month'] as int? ?? DateTime.now().month;
                  return _buildPageWithTransition(
                    context: context,
                    state: state,
                    child: BillingSendLogsPage(
                      year: year,
                      month: month,
                    ),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: 'manual',
            name: 'manual-billings',
            builder: (context, state) => const BillingAndReportsHomePage(),
            routes: [
              GoRoute(
                path: 'create',
                name: 'manual-billing-create',
                pageBuilder: (context, state) => _buildPageWithTransition(
                  context: context,
                  state: state,
                  child: const ManualBillingFormPage(),
                ),
              ),
              GoRoute(
                path: ':id/edit',
                name: 'manual-billing-edit',
                pageBuilder: (context, state) {
                  final billing = state.extra is ManualBillingModel
                      ? state.extra as ManualBillingModel
                      : null;
                  final billingId = int.tryParse(state.pathParameters['id'] ?? '');
                  return _buildPageWithTransition(
                    context: context,
                    state: state,
                    child: ManualBillingFormPage(
                      billingId: billingId,
                      billing: billing,
                    ),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: 'reports',
            name: 'billing-reports',
            builder: (context, state) => const BillingAndReportsHomePage(),
          ),
          GoRoute(
            path: 'auto/:id',
            name: 'auto-billing-details',
            pageBuilder: (context, state) {
              final billing = state.extra is AutoBillingModel
                  ? state.extra as AutoBillingModel
                  : null;
              return _buildPageWithTransition(
                context: context,
                state: state,
                child: BillingDetailsPage(autoBilling: billing),
              );
            },
          ),
          GoRoute(
            path: 'manual/:id',
            name: 'manual-billing-details',
            pageBuilder: (context, state) {
              final billing = state.extra is ManualBillingModel
                  ? state.extra as ManualBillingModel
                  : null;
              return _buildPageWithTransition(
                context: context,
                state: state,
                child: BillingDetailsPage(manualBilling: billing),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: certificates,
        name: 'certificates',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const CertificatesPage(),
        ),
      ),
      GoRoute(
        path: settings,
        name: 'settings',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const SettingsPage(),
        ),
      ),
      GoRoute(
        path: teacherPanel,
        name: 'teacher-panel',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const TeacherPanelPage(),
        ),
      ),
      GoRoute(
        path: teacherCalendar,
        name: 'teacher-calendar',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const TeacherCalendarPage(),
        ),
      ),
      GoRoute(
        path: courses,
        name: 'courses',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const CoursesListPage(),
        ),
        routes: [
          GoRoute(
            path: 'create',
            name: 'courses-create',
            pageBuilder: (context, state) => _buildPageWithTransition(
              context: context,
              state: state,
              child: const CourseFormPage(),
            ),
          ),
          GoRoute(
            path: ':id',
            name: 'course-detail',
            pageBuilder: (context, state) {
              return _buildPageWithTransition(
                context: context,
                state: state,
                child: const CoursesListPage(),
              );
            },
            routes: [
              GoRoute(
                path: 'edit',
                name: 'course-edit',
                pageBuilder: (context, state) {
                  return _buildPageWithTransition(
                    context: context,
                    state: state,
                    child: const CourseFormPage(),
                  );
                },
              ),
              GoRoute(
                path: 'lessons',
                name: 'course-lessons',
                pageBuilder: (context, state) {
                  final courseId =
                      int.tryParse(state.pathParameters['id'] ?? '');
                  return _buildPageWithTransition(
                    context: context,
                    state: state,
                    child: LessonsListPage(courseId: courseId),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: lessons,
        name: 'lessons',
        pageBuilder: (context, state) {
          final courseId = state.uri.queryParameters['courseId'] != null
              ? int.tryParse(state.uri.queryParameters['courseId']!)
              : null;
          return _buildPageWithTransition(
            context: context,
            state: state,
            child: LessonsListPage(courseId: courseId),
          );
        },
        routes: [
          GoRoute(
            path: 'create',
            name: 'lessons-create',
            pageBuilder: (context, state) {
              final courseId = state.uri.queryParameters['courseId'] != null
                  ? int.tryParse(state.uri.queryParameters['courseId']!)
                  : null;
              return _buildPageWithTransition(
                context: context,
                state: state,
                child: LessonFormPage(courseId: courseId),
              );
            },
          ),
          GoRoute(
            path: ':id',
            name: 'lesson-detail',
            pageBuilder: (context, state) {
              return _buildPageWithTransition(
                context: context,
                state: state,
                child: const LessonsListPage(),
              );
            },
            routes: [
              GoRoute(
                path: 'edit',
                name: 'lesson-edit',
                pageBuilder: (context, state) {
                  return _buildPageWithTransition(
                    context: context,
                    state: state,
                    child: const LessonFormPage(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      // Client Panel Routes
      GoRoute(
        path: '/client/dashboard',
        name: 'client-dashboard',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const ClientDashboardPage(),
        ),
      ),
      GoRoute(
        path: '/client/rooms',
        name: 'client-rooms',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const RoomsManagementPage(),
        ),
      ),
      GoRoute(
        path: '/client/subscription',
        name: 'client-subscription',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const SubscriptionPage(),
        ),
      ),
      GoRoute(
        path: '/client/settings',
        name: 'client-settings',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const ClientSettingsPage(),
        ),
      ),
    ],
  );

  /// Build page with custom transition animation
  static CustomTransitionPage _buildPageWithTransition({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        var offsetAnimation = animation.drive(tween);
        var fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeIn,
        );

        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
    );
  }

  static String _getTimetableTitleForRoute(String path) {
    if (path == calendar) return 'التقويم';
    if (path == timetables) return 'الجداول';
    return 'التقويم';
  }
}
