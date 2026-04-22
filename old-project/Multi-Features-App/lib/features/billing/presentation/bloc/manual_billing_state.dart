import 'package:equatable/equatable.dart';
import '../../data/models/manual_billing_model.dart';

abstract class ManualBillingState extends Equatable {
  const ManualBillingState();

  @override
  List<Object?> get props => [];
}

class ManualBillingInitial extends ManualBillingState {}

class ManualBillingLoading extends ManualBillingState {}

class ManualBillingsLoaded extends ManualBillingState {
  final List<ManualBillingModel> billings;

  const ManualBillingsLoaded(this.billings);

  @override
  List<Object?> get props => [billings];
}

class ManualBillingLoaded extends ManualBillingState {
  final ManualBillingModel billing;

  const ManualBillingLoaded(this.billing);

  @override
  List<Object?> get props => [billing];
}

class ManualBillingOperationSuccess extends ManualBillingState {
  final String message;

  const ManualBillingOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class ManualBillingError extends ManualBillingState {
  final String message;

  const ManualBillingError(this.message);

  @override
  List<Object?> get props => [message];
}
