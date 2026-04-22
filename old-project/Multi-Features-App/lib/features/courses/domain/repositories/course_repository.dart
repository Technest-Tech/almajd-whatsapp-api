import '../../data/models/course_model.dart';

abstract class CourseRepository {
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

