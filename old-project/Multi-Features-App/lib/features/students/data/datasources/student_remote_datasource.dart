import '../../../../core/utils/api_service.dart';
import '../models/student_model.dart';
import '../models/pagination_result.dart';

abstract class StudentRemoteDataSource {
  Future<PaginationResult> getStudents({
    String? search,
    String? country,
    String? currency,
    String? sortBy,
    String? sortOrder,
    int page = 1,
    int? perPage,
  });
  Future<StudentModel> getStudent(int id);
  Future<StudentModel> createStudent(StudentModel student);
  Future<StudentModel> updateStudent(int id, StudentModel student);
  Future<void> deleteStudent(int id);
  Future<void> bulkDeleteStudents(List<int> ids);
}

class StudentRemoteDataSourceImpl implements StudentRemoteDataSource {
  final ApiService apiService;

  StudentRemoteDataSourceImpl(this.apiService);

  @override
  Future<PaginationResult> getStudents({
    String? search,
    String? country,
    String? currency,
    String? sortBy,
    String? sortOrder,
    int page = 1,
    int? perPage,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'per_page': perPage ?? 100, // Default 100, but can be overridden for dropdowns
      if (search != null && search.isNotEmpty) 'search': search,
      if (country != null && country.isNotEmpty) 'country': country,
      if (currency != null && currency.isNotEmpty) 'currency': currency,
      if (sortBy != null) 'sort_by': sortBy,
      if (sortOrder != null) 'sort_order': sortOrder,
    };

    final response = await apiService.get('/students', queryParameters: queryParams);
    final data = response.data['data'] as List;
    final students = data.map((json) => StudentModel.fromJson(json)).toList();
    
    // Extract pagination metadata from Laravel paginator response
    final currentPage = response.data['current_page'] as int? ?? page;
    final lastPage = response.data['last_page'] as int? ?? 1;
    final responsePerPage = response.data['per_page'] as int? ?? (perPage ?? 100);
    final total = response.data['total'] as int? ?? students.length;

    return PaginationResult(
      data: students,
      currentPage: currentPage,
      lastPage: lastPage,
      perPage: responsePerPage,
      total: total,
    );
  }

  @override
  Future<StudentModel> getStudent(int id) async {
    final response = await apiService.get('/students/$id');
    return StudentModel.fromJson(response.data);
  }

  @override
  Future<StudentModel> createStudent(StudentModel student) async {
    final json = student.toJson();
    // Remove email and country when creating - backend will generate email
    json.remove('email');
    json.remove('country');
    final response = await apiService.post('/students', data: json);
    return StudentModel.fromJson(response.data);
  }

  @override
  Future<StudentModel> updateStudent(int id, StudentModel student) async {
    final json = student.toJson();
    // Remove email and country when updating - email should not be changed
    json.remove('email');
    json.remove('country');
    final response = await apiService.put('/students/$id', data: json);
    return StudentModel.fromJson(response.data);
  }

  @override
  Future<void> deleteStudent(int id) async {
    await apiService.delete('/students/$id');
  }

  @override
  Future<void> bulkDeleteStudents(List<int> ids) async {
    await apiService.post('/students/bulk-delete', data: {'ids': ids});
  }
}

