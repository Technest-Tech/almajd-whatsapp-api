import '../../data/models/student_model.dart';
import '../../data/models/pagination_result.dart';

abstract class StudentRepository {
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

