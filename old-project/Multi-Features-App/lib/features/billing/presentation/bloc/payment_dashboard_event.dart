import 'package:equatable/equatable.dart';

abstract class PaymentDashboardEvent extends Equatable {
  const PaymentDashboardEvent();

  @override
  List<Object?> get props => [];
}

class LoadPaymentDashboardStatistics extends PaymentDashboardEvent {
  final int year;
  final int month;

  const LoadPaymentDashboardStatistics({
    required this.year,
    required this.month,
  });

  @override
  List<Object?> get props => [year, month];
}
