import '../../../../core/utils/api_service.dart';
import '../models/course_model.dart';

abstract class CourseRemoteDataSource {
  Future<List<CourseModel>> getCourses({
    int? studentId,
    int? teacherId,
    String? search,
    int page = 1,
  });
  Future<CourseModel> getCourse(int id);
  Future<CourseModel> createCourse(CourseModel course);
  Future<CourseModel> updateCourse(int id, CourseModel course);
  Future<void> deleteCourse(int id);
}

class CourseRemoteDataSourceImpl implements CourseRemoteDataSource {
  final ApiService apiService;

  CourseRemoteDataSourceImpl(this.apiService);

  @override
  Future<List<CourseModel>> getCourses({
    int? studentId,
    int? teacherId,
    String? search,
    int page = 1,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'per_page': 200, // Load 200 items per page to show all courses
      if (studentId != null) 'student_id': studentId,
      if (teacherId != null) 'teacher_id': teacherId,
      if (search != null && search.isNotEmpty) 'search': search,
    };

    final response = await apiService.get('/courses', queryParameters: queryParams);
    final data = response.data['data'] as List;
    return data.map((json) => CourseModel.fromJson(json)).toList();
  }

  @override
  Future<CourseModel> getCourse(int id) async {
    final response = await apiService.get('/courses/$id');
    return CourseModel.fromJson(response.data);
  }

  @override
  Future<CourseModel> createCourse(CourseModel course) async {
    final response = await apiService.post('/courses', data: course.toJson());
    return CourseModel.fromJson(response.data);
  }

  @override
  Future<CourseModel> updateCourse(int id, CourseModel course) async {
    final response = await apiService.put('/courses/$id', data: course.toJson());
    return CourseModel.fromJson(response.data);
  }

  @override
  Future<void> deleteCourse(int id) async {
    await apiService.delete('/courses/$id');
  }
}

