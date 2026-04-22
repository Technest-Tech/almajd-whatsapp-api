import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// Authentication BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(const AuthInitial()) {
    on<LoginEvent>(_onLogin);
    on<LogoutEvent>(_onLogout);
    on<CheckAuthStatusEvent>(_onCheckAuthStatus);
  }

  /// Handle login event
  Future<void> _onLogin(LoginEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    
    try {
      final user = await _authRepository.login(event.email, event.password);
      // Only emit Authenticated if we successfully got a user
      if (user != null) {
        emit(Authenticated(user: user));
      } else {
        emit(AuthError(message: 'Failed to parse user data'));
      }
    } catch (e) {
      // Emit error state with the actual error message
      final errorMessage = e.toString().replaceAll('Exception: ', '');
      emit(AuthError(message: errorMessage));
    }
  }

  /// Handle logout event
  Future<void> _onLogout(LogoutEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    
    try {
      await _authRepository.logout();
      emit(const Unauthenticated());
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  /// Handle check auth status event
  Future<void> _onCheckAuthStatus(CheckAuthStatusEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    
    try {
      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        emit(Authenticated(user: user));
      } else {
        emit(const Unauthenticated());
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }
}


