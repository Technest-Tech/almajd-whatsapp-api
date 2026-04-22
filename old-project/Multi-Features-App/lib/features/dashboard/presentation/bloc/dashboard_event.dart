import 'package:equatable/equatable.dart';

abstract class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

class LoadAdminStats extends DashboardEvent {}

class LoadTeacherStats extends DashboardEvent {}

