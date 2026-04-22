import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/datasources/billing_remote_datasource.dart';
import 'payment_dashboard_event.dart';
import 'payment_dashboard_state.dart';

class PaymentDashboardBloc extends Bloc<PaymentDashboardEvent, PaymentDashboardState> {
  final BillingRemoteDataSource dataSource;

  PaymentDashboardBloc(this.dataSource) : super(PaymentDashboardInitial()) {
    on<LoadPaymentDashboardStatistics>(_onLoadPaymentDashboardStatistics);
  }

  Future<void> _onLoadPaymentDashboardStatistics(
    LoadPaymentDashboardStatistics event,
    Emitter<PaymentDashboardState> emit,
  ) async {
    emit(PaymentDashboardLoading());
    try {
      final statistics = await dataSource.getPaymentDashboardStatistics(
        year: event.year,
        month: event.month,
      );
      emit(PaymentDashboardLoaded(statistics));
    } catch (e) {
      emit(PaymentDashboardError(e.toString()));
    }
  }
}
