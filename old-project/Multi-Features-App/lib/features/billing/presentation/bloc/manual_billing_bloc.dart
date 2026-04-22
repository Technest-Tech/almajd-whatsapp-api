import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/datasources/billing_remote_datasource.dart';
import 'manual_billing_event.dart';
import 'manual_billing_state.dart';

class ManualBillingBloc extends Bloc<ManualBillingEvent, ManualBillingState> {
  final BillingRemoteDataSource dataSource;

  ManualBillingBloc(this.dataSource) : super(ManualBillingInitial()) {
    on<LoadManualBillings>(_onLoadManualBillings);
    on<LoadManualBilling>(_onLoadManualBilling);
    on<CreateManualBilling>(_onCreateManualBilling);
    on<UpdateManualBilling>(_onUpdateManualBilling);
    on<DeleteManualBilling>(_onDeleteManualBilling);
    on<MarkManualBillingAsPaid>(_onMarkManualBillingAsPaid);
    on<SendManualBillingWhatsApp>(_onSendManualBillingWhatsApp);
  }

  Future<void> _onLoadManualBillings(
    LoadManualBillings event,
    Emitter<ManualBillingState> emit,
  ) async {
    emit(ManualBillingLoading());
    try {
      final billings = await dataSource.getManualBillings(search: event.search);
      emit(ManualBillingsLoaded(billings));
    } catch (e) {
      emit(ManualBillingError(e.toString()));
    }
  }

  Future<void> _onLoadManualBilling(
    LoadManualBilling event,
    Emitter<ManualBillingState> emit,
  ) async {
    emit(ManualBillingLoading());
    try {
      final billing = await dataSource.getManualBilling(event.id);
      emit(ManualBillingLoaded(billing));
    } catch (e) {
      emit(ManualBillingError(e.toString()));
    }
  }

  Future<void> _onCreateManualBilling(
    CreateManualBilling event,
    Emitter<ManualBillingState> emit,
  ) async {
    emit(ManualBillingLoading());
    try {
      await dataSource.createManualBilling(event.billing);
      emit(const ManualBillingOperationSuccess('Manual billing created successfully'));
      add(const LoadManualBillings());
    } catch (e) {
      emit(ManualBillingError(e.toString()));
    }
  }

  Future<void> _onUpdateManualBilling(
    UpdateManualBilling event,
    Emitter<ManualBillingState> emit,
  ) async {
    emit(ManualBillingLoading());
    try {
      await dataSource.updateManualBilling(event.id, event.billing);
      emit(const ManualBillingOperationSuccess('Manual billing updated successfully'));
      add(const LoadManualBillings());
    } catch (e) {
      emit(ManualBillingError(e.toString()));
    }
  }

  Future<void> _onDeleteManualBilling(
    DeleteManualBilling event,
    Emitter<ManualBillingState> emit,
  ) async {
    emit(ManualBillingLoading());
    try {
      await dataSource.deleteManualBilling(event.id);
      emit(const ManualBillingOperationSuccess('Manual billing deleted successfully'));
      add(const LoadManualBillings());
    } catch (e) {
      emit(ManualBillingError(e.toString()));
    }
  }

  Future<void> _onMarkManualBillingAsPaid(
    MarkManualBillingAsPaid event,
    Emitter<ManualBillingState> emit,
  ) async {
    try {
      await dataSource.markManualBillingAsPaid(event.id);
      emit(const ManualBillingOperationSuccess('Billing marked as paid'));
      add(const LoadManualBillings());
    } catch (e) {
      emit(ManualBillingError(e.toString()));
    }
  }

  Future<void> _onSendManualBillingWhatsApp(
    SendManualBillingWhatsApp event,
    Emitter<ManualBillingState> emit,
  ) async {
    try {
      await dataSource.sendManualBillingWhatsApp(event.id);
      emit(const ManualBillingOperationSuccess('WhatsApp message sent successfully'));
    } catch (e) {
      emit(ManualBillingError(e.toString()));
    }
  }
}
