import 'package:equatable/equatable.dart';
import '../../../../core/models/user_model.dart';

/// Authentication states
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial state - app just started
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Loading state - authentication in progress
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Authenticated state - user is logged in
class Authenticated extends AuthState {
  final UserModel user;

  const Authenticated({required this.user});

  @override
  List<Object?> get props => [user];
}

/// Unauthenticated state - user is not logged in
class Unauthenticated extends AuthState {
  const Unauthenticated();
}

/// Authentication error state
class AuthError extends AuthState {
  final String message;

  const AuthError({required this.message});

  @override
  List<Object?> get props => [message];
}


