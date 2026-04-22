import 'package:equatable/equatable.dart';
import '../../data/models/student_model.dart';

abstract class StudentState extends Equatable {
  const StudentState();

  @override
  List<Object?> get props => [];
}

class StudentInitial extends StudentState {}

class StudentLoading extends StudentState {}

class StudentsLoaded extends StudentState {
  final List<StudentModel> students;
  final int currentPage;
  final bool hasMore;
  final bool isLoadingMore;
  final int maxTotalItems;

  const StudentsLoaded({
    required this.students,
    this.currentPage = 1,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.maxTotalItems = 3000,
  });

  StudentsLoaded copyWith({
    List<StudentModel>? students,
    int? currentPage,
    bool? hasMore,
    bool? isLoadingMore,
    int? maxTotalItems,
  }) {
    return StudentsLoaded(
      students: students ?? this.students,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      maxTotalItems: maxTotalItems ?? this.maxTotalItems,
    );
  }

  @override
  List<Object?> get props => [students, currentPage, hasMore, isLoadingMore, maxTotalItems];
}

class StudentLoaded extends StudentState {
  final StudentModel student;

  const StudentLoaded(this.student);

  @override
  List<Object?> get props => [student];
}

class StudentOperationSuccess extends StudentState {
  final String message;

  const StudentOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class StudentError extends StudentState {
  final String message;

  const StudentError(this.message);

  @override
  List<Object?> get props => [message];
}

