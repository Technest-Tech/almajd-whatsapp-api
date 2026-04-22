import '../../../../core/utils/api_service.dart';
import '../models/auto_billing_model.dart';
import '../models/manual_billing_model.dart';

abstract class BillingRemoteDataSource {
  // Auto Billings
  Future<List<AutoBillingModel>> getAutoBillings({
    required int year,
    required int month,
    bool? isPaid,
    String? search,
  });
  Future<AutoBillingModel> getAutoBilling(int id);
  Future<Map<String, dynamic>> getAutoBillingsTotals({
    required int year,
    required int month,
  });
  Future<void> markAutoBillingAsPaid(int id);
  Future<void> sendAutoBillingWhatsApp(int id);
  Future<Map<String, dynamic>> sendAllAutoBillingsWhatsApp({
    required int year,
    required int month,
  });
  Future<Map<String, dynamic>> getAutoBillingsSendLogs({
    required int year,
    required int month,
  });
  Future<Map<String, dynamic>> resumeSendAutoBillingsWhatsApp({
    required int year,
    required int month,
  });
  Future<List<AutoBillingModel>> generateAutoBillings({
    required int year,
    required int month,
  });

  // Manual Billings
  Future<List<ManualBillingModel>> getManualBillings({String? search});
  Future<ManualBillingModel> getManualBilling(int id);
  Future<ManualBillingModel> createManualBilling(ManualBillingModel billing);
  Future<ManualBillingModel> updateManualBilling(int id, ManualBillingModel billing);
  Future<void> deleteManualBilling(int id);
  Future<void> markManualBillingAsPaid(int id);
  Future<void> sendManualBillingWhatsApp(int id);

  // Payment Dashboard
  Future<Map<String, dynamic>> getPaymentDashboardStatistics({
    required int year,
    required int month,
  });
}

class BillingRemoteDataSourceImpl implements BillingRemoteDataSource {
  final ApiService apiService;

  BillingRemoteDataSourceImpl(this.apiService);

  @override
  Future<List<AutoBillingModel>> getAutoBillings({
    required int year,
    required int month,
    bool? isPaid,
    String? search,
  }) async {
    final queryParams = <String, dynamic>{
      'year': year,
      'month': month,
      if (isPaid != null) 'is_paid': isPaid ? 1 : 0,
      if (search != null && search.isNotEmpty) 'search': search,
    };

    final response = await apiService.get('/auto-billings', queryParameters: queryParams);
    final data = response.data['data'] as List;
    return data.map((json) => AutoBillingModel.fromJson(json)).toList();
  }

  @override
  Future<AutoBillingModel> getAutoBilling(int id) async {
    final response = await apiService.get('/auto-billings/$id');
    return AutoBillingModel.fromJson(response.data['data']);
  }

  @override
  Future<Map<String, dynamic>> getAutoBillingsTotals({
    required int year,
    required int month,
  }) async {
    final response = await apiService.get(
      '/auto-billings/totals',
      queryParameters: {'year': year, 'month': month},
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  @override
  Future<void> markAutoBillingAsPaid(int id) async {
    await apiService.post('/auto-billings/$id/mark-paid');
  }

  @override
  Future<void> sendAutoBillingWhatsApp(int id) async {
    await apiService.post('/auto-billings/$id/send-whatsapp');
  }

  @override
  Future<Map<String, dynamic>> sendAllAutoBillingsWhatsApp({
    required int year,
    required int month,
  }) async {
    final response = await apiService.post(
      '/auto-billings/send-all-whatsapp',
      data: {'year': year, 'month': month},
    );
    return {
      'batch_id': response.data['batch_id'],
      'total': response.data['total'],
      'sent': response.data['sent'],
      'failed': response.data['failed'],
      'message': response.data['message'],
    };
  }

  @override
  Future<Map<String, dynamic>> getAutoBillingsSendLogs({
    required int year,
    required int month,
  }) async {
    final response = await apiService.get(
      '/auto-billings/send-logs',
      queryParameters: {'year': year, 'month': month},
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> resumeSendAutoBillingsWhatsApp({
    required int year,
    required int month,
  }) async {
    final response = await apiService.post(
      '/auto-billings/resume-send-whatsapp',
      data: {'year': year, 'month': month},
    );
    return {
      'batch_id': response.data['batch_id'],
      'total': response.data['total'],
      'sent': response.data['sent'],
      'failed': response.data['failed'],
      'message': response.data['message'],
    };
  }

  @override
  Future<List<AutoBillingModel>> generateAutoBillings({
    required int year,
    required int month,
  }) async {
    final response = await apiService.post(
      '/auto-billings/generate',
      data: {'year': year, 'month': month},
    );
    final data = response.data['data'] as List;
    return data.map((json) => AutoBillingModel.fromJson(json)).toList();
  }

  @override
  Future<List<ManualBillingModel>> getManualBillings({String? search}) async {
    final queryParams = <String, dynamic>{
      if (search != null && search.isNotEmpty) 'search': search,
    };

    final response = await apiService.get('/manual-billings', queryParameters: queryParams);
    final data = response.data['data'] as List;
    return data.map((json) => ManualBillingModel.fromJson(json)).toList();
  }

  @override
  Future<ManualBillingModel> getManualBilling(int id) async {
    final response = await apiService.get('/manual-billings/$id');
    return ManualBillingModel.fromJson(response.data['data']);
  }

  @override
  Future<ManualBillingModel> createManualBilling(ManualBillingModel billing) async {
    final response = await apiService.post('/manual-billings', data: billing.toJson());
    return ManualBillingModel.fromJson(response.data['data']);
  }

  @override
  Future<ManualBillingModel> updateManualBilling(int id, ManualBillingModel billing) async {
    final response = await apiService.put('/manual-billings/$id', data: billing.toJson());
    return ManualBillingModel.fromJson(response.data['data']);
  }

  @override
  Future<void> deleteManualBilling(int id) async {
    await apiService.delete('/manual-billings/$id');
  }

  @override
  Future<void> markManualBillingAsPaid(int id) async {
    await apiService.post('/manual-billings/$id/mark-paid');
  }

  @override
  Future<void> sendManualBillingWhatsApp(int id) async {
    await apiService.post('/manual-billings/$id/send-whatsapp');
  }

  @override
  Future<Map<String, dynamic>> getPaymentDashboardStatistics({
    required int year,
    required int month,
  }) async {
    final response = await apiService.get(
      '/payment-dashboard/statistics',
      queryParameters: {'year': year, 'month': month},
    );
    return response.data['data'] as Map<String, dynamic>;
  }
}
