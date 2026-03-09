import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_shell.dart';
import '../../features/tickets/presentation/screens/inbox_screen.dart';
import '../../features/tickets/presentation/screens/ticket_detail_screen.dart';
import '../../features/students/presentation/screens/student_list_screen.dart';
import '../../features/students/presentation/screens/student_detail_screen.dart';
import '../../features/students/presentation/screens/student_form_screen.dart';
import '../../features/teachers/presentation/screens/teacher_list_screen.dart';
import '../../features/teachers/presentation/screens/teacher_form_screen.dart';
import '../../features/schedules/presentation/screens/schedule_list_screen.dart';
import '../../features/schedules/presentation/screens/schedule_detail_screen.dart';
import '../../features/schedules/presentation/screens/schedule_form_screen.dart';
import '../../features/sessions/presentation/screens/session_list_screen.dart';
import '../../features/sessions/presentation/screens/session_detail_screen.dart';
import '../../features/reminders/presentation/screens/reminder_list_screen.dart';
import '../../features/admin/presentation/screens/analytics_screen.dart';
import '../../features/admin/presentation/screens/user_list_screen.dart';
import '../../features/admin/presentation/screens/settings_screen.dart';
import '../../features/admin/presentation/screens/management_hub_screen.dart';
import '../../features/timetable/presentation/screens/timetable_screen.dart';
import '../../features/templates/presentation/screens/templates_screen.dart';
import '../../features/reminders/presentation/screens/classes_tracker_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      // ── Ticket Detail (outside shell — full screen) ──
      GoRoute(
        path: '/tickets/:id',
        builder: (_, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return TicketDetailScreen(ticketId: id);
        },
      ),
      // ── Student Detail (outside shell — full screen) ──
      GoRoute(
        path: '/students/new',
        builder: (_, __) => const StudentFormScreen(),
      ),
      GoRoute(
        path: '/students/:id',
        builder: (_, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return StudentDetailScreen(studentId: id);
        },
      ),
      GoRoute(
        path: '/students/:id/edit',
        builder: (_, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return StudentFormScreen(studentId: id);
        },
      ),
      // ── Teacher Forms (outside shell — full screen) ──
      GoRoute(
        path: '/teachers/new',
        builder: (_, __) => const TeacherFormScreen(),
      ),
      GoRoute(
        path: '/teachers/:id/edit',
        builder: (_, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return TeacherFormScreen(teacherId: id);
        },
      ),
      // ── Schedule Detail (outside shell — full screen) ──
      GoRoute(
        path: '/schedules/:id',
        builder: (_, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return ScheduleDetailScreen(scheduleId: id);
        },
      ),
      // ── Session Detail (outside shell — full screen) ──
      GoRoute(
        path: '/sessions/:id',
        builder: (_, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return SessionDetailScreen(sessionId: id);
        },
      ),
      // ── Dashboard Shell (role-based) ──
      ShellRoute(
        builder: (context, state, child) => DashboardShell(child: child),
        routes: [
          GoRoute(
            path: '/inbox',
            builder: (_, __) => const InboxScreen(),
          ),
          GoRoute(
            path: '/tickets',
            builder: (_, __) => const InboxScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (_, __) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/students',
            builder: (_, __) => const StudentListScreen(),
          ),
          GoRoute(
            path: '/teachers',
            builder: (_, __) => const TeacherListScreen(),
          ),
          GoRoute(
            path: '/schedules',
            builder: (_, __) => const ScheduleListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, __) => const ScheduleFormScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/sessions',
            builder: (_, __) => const SessionListScreen(),
          ),
          GoRoute(
            path: '/reminders',
            builder: (_, __) => const ReminderListScreen(),
          ),
          GoRoute(
            path: '/classes',
            builder: (_, __) => const ClassesTrackerScreen(),
          ),
          GoRoute(
            path: '/analytics',
            builder: (_, __) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: '/users',
            builder: (_, __) => const UserListScreen(),
          ),
          GoRoute(
            path: '/management',
            builder: (_, __) => const ManagementHubScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/timetable',
            builder: (_, __) => const TimetableScreen(),
          ),
          GoRoute(
            path: '/templates',
            builder: (_, __) => const TemplatesScreen(),
          ),
        ],
      ),
    ],
  );
}

