import 'package:equatable/equatable.dart';
import '../../data/models/auto_billing_model.dart';

abstract class AutoBillingEvent extends Equatable {
  const AutoBillingEvent();

  @override
  List<Object?> get props => [];
}

class LoadAutoBillings extends AutoBillingEvent {
  final int year;
  final int month;
  final bool? isPaid;
  final String? search;

  const LoadAutoBillings({
    required this.year,
    required this.month,
    this.isPaid,
    this.search,
  });

  @override
  List<Object?> get props => [year, month, isPaid, search];
}

class LoadAutoBilling extends AutoBillingEvent {
  final int id;

  const LoadAutoBilling(this.id);

  @override
  List<Object?> get props => [id];
}

class LoadAutoBillingsTotals extends AutoBillingEvent {
  final int year;
  final int month;

  const LoadAutoBillingsTotals({
    required this.year,
    required this.month,
  });

  @override
  List<Object?> get props => [year, month];
}

class GenerateAutoBillings extends AutoBillingEvent {
  final int year;
  final int month;

  const GenerateAutoBillings({
    required this.year,
    required this.month,
  });

  @override
  List<Object?> get props => [year, month];
}

class MarkAutoBillingAsPaid extends AutoBillingEvent {
  final int id;

  const MarkAutoBillingAsPaid(this.id);

  @override
  List<Object?> get props => [id];
}

class SendAutoBillingWhatsApp extends AutoBillingEvent {
  final int id;

  const SendAutoBillingWhatsApp(this.id);

  @override
  List<Object?> get props => [id];
}

class SendAllAutoBillingsWhatsApp extends AutoBillingEvent {
  final int year;
  final int month;

  const SendAllAutoBillingsWhatsApp({
    required this.year,
    required this.month,
  });

  @override
  List<Object?> get props => [year, month];
}

class LoadAutoBillingsSendLogs extends AutoBillingEvent {
  final int year;
  final int month;

  const LoadAutoBillingsSendLogs({
    required this.year,
    required this.month,
  });

  @override
  List<Object?> get props => [year, month];
}

class ResumeSendAutoBillingsWhatsApp extends AutoBillingEvent {
  final int year;
  final int month;

  const ResumeSendAutoBillingsWhatsApp({
    required this.year,
    required this.month,
  });

  @override
  List<Object?> get props => [year, month];
}
