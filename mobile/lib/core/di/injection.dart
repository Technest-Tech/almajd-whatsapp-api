import 'package:get_it/get_it.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/tickets/data/ticket_repository.dart';
import '../../features/tickets/presentation/bloc/ticket_list_bloc.dart';
import '../../features/students/data/student_repository.dart';
import '../../features/students/presentation/bloc/student_list_bloc.dart';
import '../../features/teachers/data/teacher_repository.dart';
import '../../features/teachers/presentation/bloc/teacher_list_bloc.dart';
import '../../features/schedules/data/schedule_repository.dart';
import '../../features/schedules/presentation/bloc/schedule_list_bloc.dart';
import '../../features/sessions/data/session_repository.dart';
import '../../features/sessions/presentation/bloc/session_list_bloc.dart';
import '../../features/reminders/data/reminder_repository.dart';
import '../../features/reminders/presentation/bloc/reminder_list_bloc.dart';
import '../../features/admin/data/admin_repository.dart';
import '../../features/templates/data/template_repository.dart';
import '../../features/notifications/data/notification_repository.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  // ── Core ──────────────────────────────────────────
  getIt.registerLazySingleton(() => const FlutterSecureStorage());
  getIt.registerLazySingleton(() => ApiClient(storage: getIt<FlutterSecureStorage>()));

  // ── Repositories ──────────────────────────────────
  getIt.registerLazySingleton(() => AuthRepository(
    apiClient: getIt<ApiClient>(),
    storage: getIt<FlutterSecureStorage>(),
  ));
  getIt.registerLazySingleton(() => TicketRepository(
    apiClient: getIt<ApiClient>(),
  ));
  getIt.registerLazySingleton(() => StudentRepository(
    apiClient: getIt<ApiClient>(),
  ));
  getIt.registerLazySingleton(() => TeacherRepository(
    apiClient: getIt<ApiClient>(),
  ));
  getIt.registerLazySingleton(() => ScheduleRepository(
    apiClient: getIt<ApiClient>(),
  ));
  getIt.registerLazySingleton(() => SessionRepository(
    apiClient: getIt<ApiClient>(),
  ));
  getIt.registerLazySingleton(() => ReminderRepository(
    apiClient: getIt<ApiClient>(),
  ));
  getIt.registerLazySingleton(() => AdminRepository(
    apiClient: getIt<ApiClient>(),
  ));
  getIt.registerLazySingleton(() => TemplateRepository(
    apiClient: getIt<ApiClient>(),
  ));
  getIt.registerLazySingleton(() => NotificationRepository(
    apiClient: getIt<ApiClient>(),
  ));

  // ── BLoCs ─────────────────────────────────────────
  getIt.registerFactory(() => AuthBloc(
    authRepository: getIt<AuthRepository>(),
  ));
  getIt.registerLazySingleton(() => TicketListBloc(
    ticketRepository: getIt<TicketRepository>(),
  ));
  getIt.registerFactory(() => StudentListBloc(
    studentRepository: getIt<StudentRepository>(),
  ));
  getIt.registerFactory(() => TeacherListBloc(
    teacherRepository: getIt<TeacherRepository>(),
  ));
  getIt.registerFactory(() => ScheduleListBloc(
    scheduleRepository: getIt<ScheduleRepository>(),
  ));
  getIt.registerFactory(() => SessionListBloc(
    sessionRepository: getIt<SessionRepository>(),
  ));
  getIt.registerFactory(() => ReminderListBloc(
    reminderRepository: getIt<ReminderRepository>(),
  ));
}
