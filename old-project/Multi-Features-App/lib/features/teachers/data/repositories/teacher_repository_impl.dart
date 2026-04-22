import '../../domain/repositories/teacher_repository.dart';
import '../datasources/teacher_remote_datasource.dart';
import '../models/teacher_model.dart';
import '../models/pagination_result.dart';

class TeacherRepositoryImpl implements TeacherRepository {
  final TeacherRemoteDataSource remoteDataSource;

  TeacherRepositoryImpl(this.remoteDataSource);

  @override
  Future<TeacherPaginationResult> getTeachers({String? search, int page = 1}) {
    return remoteDataSource.getTeachers(search: search, page: page);
  }

  @override
  Future<TeacherModel> getTeacher(int id) {
    return remoteDataSource.getTeacher(id);
  }

  @override
  Future<TeacherModel> createTeacher(TeacherModel teacher, String password) {
    return remoteDataSource.createTeacher(teacher, password);
  }

  @override
  Future<TeacherModel> updateTeacher(int id, TeacherModel teacher, String? password) {
    return remoteDataSource.updateTeacher(id, teacher, password);
  }

  @override
  Future<void> deleteTeacher(int id) {
    return remoteDataSource.deleteTeacher(id);
  }

  @override
  Future<List<dynamic>> getAssignedStudents(int teacherId) {
    return remoteDataSource.getAssignedStudents(teacherId);
  }

  @override
  Future<void> assignStudents(int teacherId, List<int> studentIds) {
    return remoteDataSource.assignStudents(teacherId, studentIds);
  }
}

