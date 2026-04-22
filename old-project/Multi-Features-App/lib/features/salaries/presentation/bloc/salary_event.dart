import 'package:equatable/equatable.dart';

abstract class SalaryEvent extends Equatable {
  const SalaryEvent();

  @override
  List<Object?> get props => [];
}

class LoadSalaries extends SalaryEvent {
  final int year;
  final int month;
  final double? unifiedHourPrice;

  const LoadSalaries({
    required this.year,
    required this.month,
    this.unifiedHourPrice,
  });

  @override
  List<Object?> get props => [year, month, unifiedHourPrice];
}

class ExportSalaries extends SalaryEvent {
  final int year;
  final int month;
  final double? unifiedHourPrice;

  const ExportSalaries({
    required this.year,
    required this.month,
    this.unifiedHourPrice,
  });

  @override
  List<Object?> get props => [year, month, unifiedHourPrice];
}
