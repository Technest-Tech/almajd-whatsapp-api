import '../../../core/api/api_client.dart';
import 'models/student_model.dart';

class StudentRepository {
  final ApiClient apiClient;

  StudentRepository({required this.apiClient});

  Future<List<StudentModel>> getStudents({
    String? search,
    String? status,
    int page = 1,
    int perPage = 20,
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
    await apiClient.dio.delete('/students/$id');
  }
}
