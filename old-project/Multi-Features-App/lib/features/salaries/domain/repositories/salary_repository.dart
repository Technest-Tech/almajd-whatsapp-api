import '../../data/models/salary_model.dart';

abstract class SalaryRepository {
  Future<SalariesResponseModel> getSalaries(int year, int month, {double? unifiedHourPrice});
  Future<String> getExportUrl(int year, int month, {double? unifiedHourPrice});
}
