import '../../../../core/utils/api_service.dart';
import '../models/salary_model.dart';

abstract class SalaryRemoteDataSource {
  Future<SalariesResponseModel> getSalaries(int year, int month, {double? unifiedHourPrice});
  Future<String> exportSalaries(int year, int month, {double? unifiedHourPrice});
}

class SalaryRemoteDataSourceImpl implements SalaryRemoteDataSource {
  final ApiService apiService;

  SalaryRemoteDataSourceImpl(this.apiService);

  @override
  Future<SalariesResponseModel> getSalaries(int year, int month, {double? unifiedHourPrice}) async {
    final queryParams = <String, dynamic>{
      'year': year,
      'month': month,
    };
    
    if (unifiedHourPrice != null) {
      queryParams['unified_hour_price'] = unifiedHourPrice;
    }
    
    final response = await apiService.get(
      '/salaries',
      queryParameters: queryParams,
    );

    if (response.data is! Map<String, dynamic>) {
      throw Exception('Invalid response format');
    }

    return SalariesResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<String> exportSalaries(int year, int month, {double? unifiedHourPrice}) async {
    // Return the full API endpoint URL for download
    final baseUrl = ApiService.baseUrl;
    var url = '$baseUrl/salaries/export?year=$year&month=$month';
    if (unifiedHourPrice != null) {
      url += '&unified_hour_price=$unifiedHourPrice';
    }
    return url;
  }
}
