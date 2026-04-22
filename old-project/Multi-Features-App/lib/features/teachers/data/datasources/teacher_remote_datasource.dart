import '../../../../core/utils/api_service.dart';
import '../models/teacher_model.dart';
import '../models/pagination_result.dart';

abstract class TeacherRemoteDataSource {
  Future<TeacherPaginationResult> getTeachers({String? search, int page = 1});
  Future<TeacherModel> getTeacher(int id);
  Future<TeacherModel> createTeacher(TeacherModel teacher, String password);
  Future<TeacherModel> updateTeacher(int id, TeacherModel teacher, String? password);
  Future<void> deleteTeacher(int id);
  Future<List<dynamic>> getAssignedStudents(int teacherId);
  Future<void> assignStudents(int teacherId, List<int> studentIds);
}

class TeacherRemoteDataSourceImpl implements TeacherRemoteDataSource {
  final ApiService apiService;

  TeacherRemoteDataSourceImpl(this.apiService);

  @override
  Future<TeacherPaginationResult> getTeachers({String? search, int page = 1}) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'per_page': 100, // Load 100 items per page (up to 3000 total)
      if (search != null && search.isNotEmpty) 'search': search,
    };

    final response = await apiService.get('/teachers', queryParameters: queryParams);
    final data = response.data['data'] as List;
    final teachers = data.map((json) => TeacherModel.fromJson(json)).toList();
    
    // Extract pagination metadata from Laravel paginator response
    final currentPage = response.data['current_page'] as int? ?? page;
    final lastPage = response.data['last_page'] as int? ?? 1;
    final perPage = response.data['per_page'] as int? ?? 100;
    final total = response.data['total'] as int? ?? teachers.length;

    return TeacherPaginationResult(
      data: teachers,
      currentPage: currentPage,
      lastPage: lastPage,
      perPage: perPage,
      total: total,
    );
  }

  @override
  Future<TeacherModel> getTeacher(int id) async {
    final response = await apiService.get('/teachers/$id');
    return TeacherModel.fromJson(response.data);
  }

  @override
  Future<TeacherModel> createTeacher(TeacherModel teacher, String password) async {
    final data = teacher.toJson();
    data['password'] = password;
    // Remove country field - not needed for teachers
    data.remove('country');
    final response = await apiService.post('/teachers', data: data);
    return TeacherModel.fromJson(response.data);
  }

  @override
  Future<TeacherModel> updateTeacher(int id, TeacherModel teacher, String? password) async {
    final data = teacher.toJson();
    if (password != null && password.isNotEmpty) {
      data['password'] = password;
    }
    // Remove country field - not needed for teachers
    data.remove('country');
    final response = await apiService.put('/teachers/$id', data: data);
    return TeacherModel.fromJson(response.data);
  }

  @override
  Future<void> deleteTeacher(int id) async {
    await apiService.delete('/teachers/$id');
  }

  @override
  Future<List<dynamic>> getAssignedStudents(int teacherId) async {
    final response = await apiService.get('/teachers/$teacherId/students');
    return response.data as List;
  }

  @override
  Future<void> assignStudents(int teacherId, List<int> studentIds) async {
    await apiService.post(
      '/teachers/$teacherId/assign-students',
      data: {'student_ids': studentIds},
    );
  }
}

