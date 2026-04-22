import '../../domain/repositories/student_repository.dart';
import '../datasources/student_remote_datasource.dart';
import '../models/student_model.dart';
import '../models/pagination_result.dart';

class StudentRepositoryImpl implements StudentRepository {
  final StudentRemoteDataSource remoteDataSource;

  StudentRepositoryImpl(this.remoteDataSource);

  @override
  Future<PaginationResult> getStudents({
    String? search,
    String? country,
    String? currency,
    String? sortBy,
    String? sortOrder,
    int page = 1,
    int? perPage,
  }) {
    return remoteDataSource.getStudents(
      search: search,
      country: country,
      currency: currency,
      sortBy: sortBy,
      sortOrder: sortOrder,
      page: page,
      perPage: perPage,
    );
  }

  @override
  Future<StudentModel> getStudent(int id) {
    return remoteDataSource.getStudent(id);
  }

  @override
  Future<StudentModel> createStudent(StudentModel student) {
    return remoteDataSource.createStudent(student);
  }

  @override
  Future<StudentModel> updateStudent(int id, StudentModel student) {
    return remoteDataSource.updateStudent(id, student);
  }

  @override
  Future<void> deleteStudent(int id) {
    return remoteDataSource.deleteStudent(id);
  }

  @override
  Future<void> bulkDeleteStudents(List<int> ids) {
    return remoteDataSource.bulkDeleteStudents(ids);
  }
}

