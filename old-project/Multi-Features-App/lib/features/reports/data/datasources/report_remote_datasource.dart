import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../../core/utils/api_service.dart';

abstract class ReportRemoteDataSource {
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

class ReportRemoteDataSourceImpl implements ReportRemoteDataSource {
  final ApiService apiService;

  ReportRemoteDataSourceImpl(this.apiService);

  @override
  Future<Uint8List> generateStudentReport({
    required int studentId,
    required String fromDate,
    required String toDate,
  }) async {
    try {
      final response = await apiService.dio.post(
        '/reports/student',
        data: {
          'student_id': studentId,
          'from_date': fromDate,
          'to_date': toDate,
        },
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Accept': 'application/pdf',
          },
        ),
      );
      
      return Uint8List.fromList(response.data);
    } catch (e) {
      throw Exception('Failed to generate student report: $e');
    }
  }

  @override
  Future<Uint8List> generateMultiStudentReport({
    required List<int> studentIds,
    required String fromDate,
    required String toDate,
  }) async {
    try {
      final response = await apiService.dio.post(
        '/reports/multi-student',
        data: {
          'student_ids': studentIds,
          'from_date': fromDate,
          'to_date': toDate,
        },
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Accept': 'application/pdf',
          },
        ),
      );
      
      return Uint8List.fromList(response.data);
    } catch (e) {
      throw Exception('Failed to generate multi-student report: $e');
    }
  }

  @override
  Future<Uint8List> generateAcademyStatisticsReport({
    required String fromDate,
    required String toDate,
  }) async {
    try {
      final response = await apiService.dio.post(
        '/reports/academy-statistics',
        data: {
          'from_date': fromDate,
          'to_date': toDate,
        },
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Accept': 'application/pdf',
          },
        ),
      );
      
      return Uint8List.fromList(response.data);
    } catch (e) {
      throw Exception('Failed to generate academy statistics report: $e');
    }
  }
}
