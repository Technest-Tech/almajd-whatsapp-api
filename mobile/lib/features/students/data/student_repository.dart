import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import 'models/student_model.dart';
import '../../schedules/data/models/schedule_model.dart';

class StudentRepository {
  final ApiClient apiClient;

  StudentRepository({required this.apiClient});

  Future<List<StudentModel>> getStudents({
    String? search,
    String? status,
    int page = 1,
    int perPage = 5000,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (status != null && status != 'all') params['status'] = status;

    final response = await apiClient.dio.get('/students', queryParameters: params);
    final List data = response.data['data'];
    return data.map((j) => StudentModel.fromJson(j)).toList();
  }

  Future<StudentModel> getStudent(int id) async {
    final response = await apiClient.dio.get('/students/$id');
    return StudentModel.fromJson(response.data['data']);
  }

  Future<StudentModel> createStudent(Map<String, dynamic> data) async {
    final response = await apiClient.dio.post('/students', data: data);
    return StudentModel.fromJson(response.data['data']);
  }

  Future<StudentModel> updateStudent(int id, Map<String, dynamic> data) async {
    final response = await apiClient.dio.put('/students/$id', data: data);
    return StudentModel.fromJson(response.data['data']);
  }

  Future<void> deleteStudent(int id) async {
    await apiClient.dio.delete(
      '/students/$id',
      options: Options(responseType: ResponseType.plain),
    );
  }

  Future<List<ScheduleEntryModel>> getScheduleEntries(int studentId) async {
    final response = await apiClient.dio.get('/students/$studentId/schedule-entries');
    final List data = response.data['data'];
    return data.map((j) => ScheduleEntryModel.fromJson(j)).toList();
  }

  Future<void> deleteScheduleEntry(int studentId, int entryId) async {
    await apiClient.dio.delete(
      '/students/$studentId/schedule-entries/$entryId',
      options: Options(responseType: ResponseType.plain),
    );
  }

  Future<ScheduleEntryModel> createScheduleEntry(int studentId, Map<String, dynamic> data) async {
    final response = await apiClient.dio.post('/students/$studentId/schedule-entries', data: data);
    return ScheduleEntryModel.fromJson(response.data['data']);
  }

  Future<ScheduleEntryModel> updateScheduleEntry(int studentId, int entryId, Map<String, dynamic> data) async {
    final response = await apiClient.dio.put('/students/$studentId/schedule-entries/$entryId', data: data);
    return ScheduleEntryModel.fromJson(response.data['data']);
  }

  Future<Map<String, dynamic>> generateClassSessions(int studentId, {int? month, int? year}) async {
    final now = DateTime.now();
    final response = await apiClient.dio.post(
      '/students/$studentId/generate-sessions',
      data: {'month': month ?? now.month, 'year': year ?? now.year},
    );
    return response.data;
  }

  Future<List<dynamic>> getClassSessions(int studentId, {int? month, int? year}) async {
    final now = DateTime.now();
    final response = await apiClient.dio.get(
      '/students/$studentId/class-sessions',
      queryParameters: {'month': month ?? now.month, 'year': year ?? now.year},
    );
    final List data = response.data['data'];
    return data;
  }
}
