import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/datasources/billing_remote_datasource.dart';
import 'auto_billing_event.dart';
import 'auto_billing_state.dart';

class AutoBillingBloc extends Bloc<AutoBillingEvent, AutoBillingState> {
  final BillingRemoteDataSource dataSource;

  AutoBillingBloc(this.dataSource) : super(AutoBillingInitial()) {
    on<LoadAutoBillings>(_onLoadAutoBillings);
    on<LoadAutoBilling>(_onLoadAutoBilling);
    on<LoadAutoBillingsTotals>(_onLoadAutoBillingsTotals);
    on<GenerateAutoBillings>(_onGenerateAutoBillings);
    on<MarkAutoBillingAsPaid>(_onMarkAutoBillingAsPaid);
    on<SendAutoBillingWhatsApp>(_onSendAutoBillingWhatsApp);
    on<SendAllAutoBillingsWhatsApp>(_onSendAllAutoBillingsWhatsApp);
    on<LoadAutoBillingsSendLogs>(_onLoadAutoBillingsSendLogs);
    on<ResumeSendAutoBillingsWhatsApp>(_onResumeSendAutoBillingsWhatsApp);
  }

  Future<void> _onLoadAutoBillings(
    LoadAutoBillings event,
    Emitter<AutoBillingState> emit,
  ) async {
    emit(AutoBillingLoading());
    try {
      final billings = await dataSource.getAutoBillings(
        year: event.year,
        month: event.month,
        isPaid: event.isPaid,
        search: event.search,
      );
      final totals = await dataSource.getAutoBillingsTotals(
        year: event.year,
        month: event.month,
      );
      emit(AutoBillingsLoaded(billings, totals: totals));
    } catch (e) {
      emit(AutoBillingError(e.toString()));
    }
  }

  Future<void> _onLoadAutoBilling(
    LoadAutoBilling event,
    Emitter<AutoBillingState> emit,
  ) async {
    emit(AutoBillingLoading());
    try {
      final billing = await dataSource.getAutoBilling(event.id);
      emit(AutoBillingLoaded(billing));
    } catch (e) {
      emit(AutoBillingError(e.toString()));
    }
  }

  Future<void> _onLoadAutoBillingsTotals(
    LoadAutoBillingsTotals event,
    Emitter<AutoBillingState> emit,
  ) async {
    try {
      final totals = await dataSource.getAutoBillingsTotals(
        year: event.year,
        month: event.month,
      );
      if (state is AutoBillingsLoaded) {
        emit(AutoBillingsLoaded(
          (state as AutoBillingsLoaded).billings,
          totals: totals,
        ));
      }
    } catch (e) {
      emit(AutoBillingError(e.toString()));
    }
  }

  Future<void> _onGenerateAutoBillings(
    GenerateAutoBillings event,
    Emitter<AutoBillingState> emit,
  ) async {
    emit(AutoBillingLoading());
    try {
      await dataSource.generateAutoBillings(
        year: event.year,
        month: event.month,
      );
      emit(const AutoBillingOperationSuccess('Auto billings generated successfully'));
      add(LoadAutoBillings(year: event.year, month: event.month));
    } catch (e) {
      emit(AutoBillingError(e.toString()));
    }
  }

  Future<void> _onMarkAutoBillingAsPaid(
    MarkAutoBillingAsPaid event,
    Emitter<AutoBillingState> emit,
  ) async {
    try {
      await dataSource.markAutoBillingAsPaid(event.id);
      emit(const AutoBillingOperationSuccess('Billing marked as paid'));
      // Reload current billings if state has filters
      if (state is AutoBillingsLoaded) {
        final currentState = state as AutoBillingsLoaded;
        // We need to reload, but we don't have year/month in state
        // So we'll just emit success and let UI reload
      }
    } catch (e) {
      emit(AutoBillingError(e.toString()));
    }
  }

  Future<void> _onSendAutoBillingWhatsApp(
    SendAutoBillingWhatsApp event,
    Emitter<AutoBillingState> emit,
  ) async {
    try {
      await dataSource.sendAutoBillingWhatsApp(event.id);
      emit(const AutoBillingOperationSuccess('WhatsApp message sent successfully'));
    } catch (e) {
      emit(AutoBillingError(e.toString()));
    }
  }

  Future<void> _onSendAllAutoBillingsWhatsApp(
    SendAllAutoBillingsWhatsApp event,
    Emitter<AutoBillingState> emit,
  ) async {
    // Save current state to restore bills if error occurs
    AutoBillingsLoaded? previousState;
    if (state is AutoBillingsLoaded) {
      previousState = state as AutoBillingsLoaded;
    }
    
    try {
      // Don't emit sending state initially since we don't know the count yet
      // The backend will handle the sending and return results
      final result = await dataSource.sendAllAutoBillingsWhatsApp(
        year: event.year,
        month: event.month,
      );
      
      // Safely extract values with null handling
      final batchId = result['batch_id']?.toString() ?? '';
      final total = (result['total'] as num?)?.toInt() ?? 0;
      final sent = (result['sent'] as num?)?.toInt() ?? 0;
      final failed = (result['failed'] as num?)?.toInt() ?? 0;
      final message = result['message']?.toString() ?? 'Messages queued successfully';
      
      emit(AutoBillingsSendComplete(
        batchId: batchId,
        total: total,
        sent: sent,
        failed: failed,
        message: message,
      ));
      
      // Reload billings to refresh the list after sending
      add(LoadAutoBillings(year: event.year, month: event.month));
    } catch (e) {
      // Emit error first for listener to show snackbar
      emit(AutoBillingError(e.toString()));
      // Then restore previous state to keep bills visible
      if (previousState != null) {
        emit(AutoBillingsLoaded(
          previousState.billings,
          totals: previousState.totals,
          errorMessage: e.toString(),
        ));
      }
      // Immediately reload to ensure bills are visible
      add(LoadAutoBillings(year: event.year, month: event.month));
    }
  }

  Future<void> _onLoadAutoBillingsSendLogs(
    LoadAutoBillingsSendLogs event,
    Emitter<AutoBillingState> emit,
  ) async {
    try {
      final logsData = await dataSource.getAutoBillingsSendLogs(
        year: event.year,
        month: event.month,
      );
      emit(AutoBillingsSendLogsLoaded(logsData));
    } catch (e) {
      emit(AutoBillingError(e.toString()));
    }
  }

  Future<void> _onResumeSendAutoBillingsWhatsApp(
    ResumeSendAutoBillingsWhatsApp event,
    Emitter<AutoBillingState> emit,
  ) async {
    // Save current state to restore bills if error occurs
    AutoBillingsLoaded? previousState;
    if (state is AutoBillingsLoaded) {
      previousState = state as AutoBillingsLoaded;
    }
    
    try {
      final result = await dataSource.resumeSendAutoBillingsWhatsApp(
        year: event.year,
        month: event.month,
      );
      
      // Safely extract values with null handling
      final batchId = result['batch_id']?.toString() ?? '';
      final total = (result['total'] as num?)?.toInt() ?? 0;
      final sent = (result['sent'] as num?)?.toInt() ?? 0;
      final failed = (result['failed'] as num?)?.toInt() ?? 0;
      final message = result['message']?.toString() ?? 'Resume sending completed';
      
      emit(AutoBillingsSendComplete(
        batchId: batchId,
        total: total,
        sent: sent,
        failed: failed,
        message: message,
      ));
      // Reload logs after resuming
      add(LoadAutoBillingsSendLogs(year: event.year, month: event.month));
    } catch (e) {
      // Emit error first for listener to show snackbar
      emit(AutoBillingError(e.toString()));
      // Then restore previous state to keep bills visible
      if (previousState != null) {
        emit(AutoBillingsLoaded(
          previousState.billings,
          totals: previousState.totals,
          errorMessage: e.toString(),
        ));
      }
    }
  }
}
