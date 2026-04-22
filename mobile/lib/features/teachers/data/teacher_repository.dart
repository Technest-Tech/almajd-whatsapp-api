import '../../../core/api/api_client.dart';
import 'models/teacher_model.dart';

class TeacherRepository {
  final ApiClient apiClient;

  TeacherRepository({required this.apiClient});

  Future<List<dynamic>> getTeacherSessions(int teacherId) async {
    print('DEBUG: Calling /sessions with teacher_id=$teacherId');
    final response = await apiClient.dio.get(
      '/sessions',
      queryParameters: {'teacher_id': teacherId, 'per_page': 1000},
    );
    final List data = response.data['data'];
    print('DEBUG: /sessions returned ${data.length} items for teacher $teacherId');
    return data;
  }

  Future<List<TeacherModel>> getTeachers({
    String? search,
    int page = 1,
    int perPage = 5000,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };
    if (search != null && search.isNotEmpty) params['search'] = search;

    final response = await apiClient.dio.get('/teachers', queryParameters: params);
    final List data = response.data['data'];
    return data.map((j) => TeacherModel.fromJson(j)).toList();
  }

  Future<TeacherModel> getTeacher(int id) async {
    final response = await apiClient.dio.get('/teachers/$id');
    return TeacherModel.fromJson(response.data['data']);
  }

  Future<TeacherModel> createTeacher(Map<String, dynamic> data) async {
    final response = await apiClient.dio.post('/teachers', data: data);
    return TeacherModel.fromJson(response.data['data']);
  }

  Future<TeacherModel> updateTeacher(int id, Map<String, dynamic> data) async {
    final response = await apiClient.dio.put('/teachers/$id', data: data);
    return TeacherModel.fromJson(response.data['data']);
  }

  Future<void> deleteTeacher(int id) async {
    await apiClient.dio.delete('/teachers/$id');
  }
}
