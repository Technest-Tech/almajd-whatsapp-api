import '../../data/models/teacher_model.dart';
import '../../data/models/pagination_result.dart';

abstract class TeacherRepository {
  Future<TeacherPaginationResult> getTeachers({String? search, int page = 1});
  Future<TeacherModel> getTeacher(int id);
  Future<TeacherModel> createTeacher(TeacherModel teacher, String password);
  Future<TeacherModel> updateTeacher(int id, TeacherModel teacher, String? password);
  Future<void> deleteTeacher(int id);
  Future<List<dynamic>> getAssignedStudents(int teacherId);
  Future<void> assignStudents(int teacherId, List<int> studentIds);
}

