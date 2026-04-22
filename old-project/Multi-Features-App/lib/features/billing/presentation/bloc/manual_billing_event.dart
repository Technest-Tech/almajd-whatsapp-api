import 'package:equatable/equatable.dart';
import '../../data/models/manual_billing_model.dart';

abstract class ManualBillingEvent extends Equatable {
  const ManualBillingEvent();

  @override
  List<Object?> get props => [];
}

class LoadManualBillings extends ManualBillingEvent {
  final String? search;

  const LoadManualBillings({this.search});

  @override
  List<Object?> get props => [search];
}

class LoadManualBilling extends ManualBillingEvent {
  final int id;

  const LoadManualBilling(this.id);

  @override
  List<Object?> get props => [id];
}

class CreateManualBilling extends ManualBillingEvent {
  final ManualBillingModel billing;

  const CreateManualBilling(this.billing);

  @override
  List<Object?> get props => [billing];
}

class UpdateManualBilling extends ManualBillingEvent {
  final int id;
  final ManualBillingModel billing;

  const UpdateManualBilling(this.id, this.billing);

  @override
  List<Object?> get props => [id, billing];
}

class DeleteManualBilling extends ManualBillingEvent {
  final int id;

  const DeleteManualBilling(this.id);

  @override
  List<Object?> get props => [id];
}

class MarkManualBillingAsPaid extends ManualBillingEvent {
  final int id;

  const MarkManualBillingAsPaid(this.id);

  @override
  List<Object?> get props => [id];
}

class SendManualBillingWhatsApp extends ManualBillingEvent {
  final int id;

  const SendManualBillingWhatsApp(this.id);

  @override
  List<Object?> get props => [id];
}
