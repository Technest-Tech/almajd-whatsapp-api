import 'package:equatable/equatable.dart';
import '../../data/models/auto_billing_model.dart';

abstract class AutoBillingState extends Equatable {
  const AutoBillingState();

  @override
  List<Object?> get props => [];
}

class AutoBillingInitial extends AutoBillingState {}

class AutoBillingLoading extends AutoBillingState {}

class AutoBillingsLoaded extends AutoBillingState {
  final List<AutoBillingModel> billings;
  final Map<String, dynamic>? totals;
  final String? errorMessage;

  const AutoBillingsLoaded(this.billings, {this.totals, this.errorMessage});

  @override
  List<Object?> get props => [billings, totals, errorMessage];
}

class AutoBillingLoaded extends AutoBillingState {
  final AutoBillingModel billing;

  const AutoBillingLoaded(this.billing);

  @override
  List<Object?> get props => [billing];
}

class AutoBillingOperationSuccess extends AutoBillingState {
  final String message;

  const AutoBillingOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class AutoBillingError extends AutoBillingState {
  final String message;

  const AutoBillingError(this.message);

  @override
  List<Object?> get props => [message];
}

class AutoBillingsSending extends AutoBillingState {
  final String batchId;
  final int total;
  final int sent;
  final int failed;

  const AutoBillingsSending({
    required this.batchId,
    required this.total,
    required this.sent,
    required this.failed,
  });

  @override
  List<Object?> get props => [batchId, total, sent, failed];
}

class AutoBillingsSendComplete extends AutoBillingState {
  final String batchId;
  final int total;
  final int sent;
  final int failed;
  final String message;

  const AutoBillingsSendComplete({
    required this.batchId,
    required this.total,
    required this.sent,
    required this.failed,
    required this.message,
  });

  @override
  List<Object?> get props => [batchId, total, sent, failed, message];
}

class AutoBillingsSendLogsLoaded extends AutoBillingState {
  final Map<String, dynamic> logsData;

  const AutoBillingsSendLogsLoaded(this.logsData);

  @override
  List<Object?> get props => [logsData];
}
