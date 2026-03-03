import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/auth_repository.dart';
import '../../data/models/user_model.dart';

// ── Events ──────────────────────────────────────────

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthCheckStatus extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class AuthDemoLogin extends AuthEvent {}

class AuthLogoutRequested extends AuthEvent {}

class AuthAvailabilityChanged extends AuthEvent {
  final String availability;
  const AuthAvailabilityChanged(this.availability);

  @override
  List<Object?> get props => [availability];
}

// ── States ──────────────────────────────────────────

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final UserModel user;
  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

// ── BLoC ──────────────────────────────────────────

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;
  static bool demoMode = false;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<AuthCheckStatus>(_onCheckStatus);
    on<AuthLoginRequested>(_onLogin);
    on<AuthDemoLogin>(_onDemoLogin);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthAvailabilityChanged>(_onAvailabilityChanged);
  }

  Future<void> _onCheckStatus(AuthCheckStatus event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final hasToken = await authRepository.hasValidToken();
      if (hasToken) {
        final user = await authRepository.getProfile();
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (_) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLogin(AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.login(
        email: event.email,
        password: event.password,
      );
      emit(AuthAuthenticated(user));
    } catch (e) {
      String message = 'فشل تسجيل الدخول';
      if (e.toString().contains('401')) {
        message = 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      } else if (e.toString().contains('SocketException') || e.toString().contains('timeout')) {
        message = 'لا يوجد اتصال بالخادم';
      }
      emit(AuthError(message));
    }
  }

  Future<void> _onDemoLogin(AuthDemoLogin event, Emitter<AuthState> emit) async {
    demoMode = true;
    emit(AuthLoading());
    await Future.delayed(const Duration(milliseconds: 800));
    emit(const AuthAuthenticated(UserModel(
      id: 1,
      name: 'أحمد المشرف',
      email: 'admin@almajd.com',
      phone: '+966501234567',
      availability: 'available',
      maxOpenTickets: 10,
      roles: ['admin'],
    )));
  }

  Future<void> _onLogout(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    demoMode = false;
    await authRepository.logout();
    emit(AuthUnauthenticated());
  }

  Future<void> _onAvailabilityChanged(AuthAvailabilityChanged event, Emitter<AuthState> emit) async {
    if (demoMode) return;
    try {
      await authRepository.updateAvailability(event.availability);
      if (state is AuthAuthenticated) {
        final user = await authRepository.getProfile();
        emit(AuthAuthenticated(user));
      }
    } catch (_) {}
  }
}

