import 'dart:typed_data';

abstract class ReportRepository {
  Future<Uint8List> generateStudentReport({
    required int studentId,
    required String fromDate,
    required String toDate,
  });
  
  Future<Uint8List> generateMultiStudentReport({
    required List<int> studentIds,
    required String fromDate,
    required String toDate,
  });
  
  Future<Uint8List> generateAcademyStatisticsReport({
    required String fromDate,
    required String toDate,
  });
}
