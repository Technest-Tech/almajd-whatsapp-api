import '../../domain/repositories/salary_repository.dart';
import '../datasources/salary_remote_datasource.dart';
import '../models/salary_model.dart';

class SalaryRepositoryImpl implements SalaryRepository {
  final SalaryRemoteDataSource remoteDataSource;

  SalaryRepositoryImpl(this.remoteDataSource);

  @override
  Future<SalariesResponseModel> getSalaries(int year, int month, {double? unifiedHourPrice}) {
    return remoteDataSource.getSalaries(year, month, unifiedHourPrice: unifiedHourPrice);
  }

  @override
  Future<String> getExportUrl(int year, int month, {double? unifiedHourPrice}) {
    return remoteDataSource.exportSalaries(year, month, unifiedHourPrice: unifiedHourPrice);
  }
}
