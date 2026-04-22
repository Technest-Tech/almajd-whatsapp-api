import 'student_model.dart';

class PaginationResult {
  final List<StudentModel> data;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  PaginationResult({
    required this.data,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  bool get hasMore => currentPage < lastPage;
}
