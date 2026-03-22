import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/auth_repository.dart';
import '../../data/models/user_model.dart';
import '../../../../core/api/websockets_client.dart';

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
  // Used to prevent async race conditions where an old AuthCheckStatus finishes
  // after a successful login and overwrites AuthAuthenticated with AuthUnauthenticated.
  int _authMutationId = 0;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<AuthCheckStatus>(_onCheckStatus);
    on<AuthLoginRequested>(_onLogin);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthAvailabilityChanged>(_onAvailabilityChanged);
  }

  Future<void> _onCheckStatus(AuthCheckStatus event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final mutationAtStart = _authMutationId;
    try {
      final hasToken = await authRepository.hasValidToken();
      if (hasToken) {
        final user = await authRepository.getProfile();
        if (mutationAtStart != _authMutationId) return;
        // Websocket setup should not break auth flow.
        try {
          await WebSocketsClient.instance.init(authRepository.storage);
        } catch (_) {}
        emit(AuthAuthenticated(user));
      } else {
        if (mutationAtStart != _authMutationId) return;
        emit(AuthUnauthenticated());
      }
    } catch (e, stackTrace) {
      print('AUTH CHECK ERROR: $e');
      print('STACK: $stackTrace');
      if (mutationAtStart != _authMutationId) return;
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLogin(AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    _authMutationId++;
    try {
      final user = await authRepository.login(
        email: event.email,
        password: event.password,
      );
      // Login should succeed even if websocket connection fails.
      try {
        await WebSocketsClient.instance.init(authRepository.storage);
      } catch (_) {}
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

  Future<void> _onLogout(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    _authMutationId++;
    await authRepository.logout();
    WebSocketsClient.instance.disconnect();
    emit(AuthUnauthenticated());
  }

  Future<void> _onAvailabilityChanged(AuthAvailabilityChanged event, Emitter<AuthState> emit) async {
    try {
      await authRepository.updateAvailability(event.availability);
      if (state is AuthAuthenticated) {
        final user = await authRepository.getProfile();
        emit(AuthAuthenticated(user));
      }
    } catch (_) {}
  }
}
