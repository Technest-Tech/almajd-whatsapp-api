import 'package:equatable/equatable.dart';

abstract class PaymentDashboardState extends Equatable {
  const PaymentDashboardState();

  @override
  List<Object?> get props => [];
}

class PaymentDashboardInitial extends PaymentDashboardState {}

class PaymentDashboardLoading extends PaymentDashboardState {}

class PaymentDashboardLoaded extends PaymentDashboardState {
  final Map<String, dynamic> statistics;

  const PaymentDashboardLoaded(this.statistics);

  @override
  List<Object?> get props => [statistics];
}

class PaymentDashboardError extends PaymentDashboardState {
  final String message;

  const PaymentDashboardError(this.message);

  @override
  List<Object?> get props => [message];
}
