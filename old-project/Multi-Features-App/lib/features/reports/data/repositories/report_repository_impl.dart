import 'dart:typed_data';
import '../../domain/repositories/report_repository.dart';
import '../datasources/report_remote_datasource.dart';

class ReportRepositoryImpl implements ReportRepository {
  final ReportRemoteDataSource remoteDataSource;

  ReportRepositoryImpl(this.remoteDataSource);

  @override
  Future<Uint8List> generateStudentReport({
    required int studentId,
    required String fromDate,
    required String toDate,
  }) {
    return remoteDataSource.generateStudentReport(
      studentId: studentId,
      fromDate: fromDate,
      toDate: toDate,
    );
  }

  @override
  Future<Uint8List> generateMultiStudentReport({
    required List<int> studentIds,
    required String fromDate,
    required String toDate,
  }) {
    return remoteDataSource.generateMultiStudentReport(
      studentIds: studentIds,
      fromDate: fromDate,
      toDate: toDate,
    );
  }

  @override
  Future<Uint8List> generateAcademyStatisticsReport({
    required String fromDate,
    required String toDate,
  }) {
    return remoteDataSource.generateAcademyStatisticsReport(
      fromDate: fromDate,
      toDate: toDate,
    );
  }
}
