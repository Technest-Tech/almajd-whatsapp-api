import 'teacher_model.dart';

class TeacherPaginationResult {
  final List<TeacherModel> data;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  TeacherPaginationResult({
    required this.data,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  bool get hasMore => currentPage < lastPage;
}
