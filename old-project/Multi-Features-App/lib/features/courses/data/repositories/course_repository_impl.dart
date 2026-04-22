import '../../domain/repositories/course_repository.dart';
import '../datasources/course_remote_datasource.dart';
import '../models/course_model.dart';

class CourseRepositoryImpl implements CourseRepository {
  final CourseRemoteDataSource remoteDataSource;

  CourseRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<CourseModel>> getCourses({
    int? studentId,
    int? teacherId,
    String? search,
    int page = 1,
  }) {
    return remoteDataSource.getCourses(
      studentId: studentId,
      teacherId: teacherId,
      search: search,
      page: page,
    );
  }

  @override
  Future<CourseModel> getCourse(int id) {
    return remoteDataSource.getCourse(id);
  }

  @override
  Future<CourseModel> createCourse(CourseModel course) {
    return remoteDataSource.createCourse(course);
  }

  @override
  Future<CourseModel> updateCourse(int id, CourseModel course) {
    return remoteDataSource.updateCourse(id, course);
  }

  @override
  Future<void> deleteCourse(int id) {
    return remoteDataSource.deleteCourse(id);
  }
}

