import 'package:equatable/equatable.dart';

abstract class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class AdminStatsLoaded extends DashboardState {
  final Map<String, dynamic> stats;

  const AdminStatsLoaded(this.stats);

  @override
  List<Object?> get props => [stats];
}

class TeacherStatsLoaded extends DashboardState {
  final Map<String, dynamic> stats;

  const TeacherStatsLoaded(this.stats);

  @override
  List<Object?> get props => [stats];
}

class DashboardError extends DashboardState {
  final String message;

  const DashboardError(this.message);

  @override
  List<Object?> get props => [message];
}

