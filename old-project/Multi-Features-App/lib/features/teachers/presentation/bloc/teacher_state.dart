import 'package:equatable/equatable.dart';
import '../../data/models/teacher_model.dart';

abstract class TeacherState extends Equatable {
  const TeacherState();

  @override
  List<Object?> get props => [];
}

class TeacherInitial extends TeacherState {}

class TeacherLoading extends TeacherState {}

class TeachersLoaded extends TeacherState {
  final List<TeacherModel> teachers;
  final int currentPage;
  final bool hasMore;
  final bool isLoadingMore;
  final int maxTotalItems;

  const TeachersLoaded({
    required this.teachers,
    this.currentPage = 1,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.maxTotalItems = 3000,
  });

  TeachersLoaded copyWith({
    List<TeacherModel>? teachers,
    int? currentPage,
    bool? hasMore,
    bool? isLoadingMore,
    int? maxTotalItems,
  }) {
    return TeachersLoaded(
      teachers: teachers ?? this.teachers,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      maxTotalItems: maxTotalItems ?? this.maxTotalItems,
    );
  }

  @override
  List<Object?> get props => [teachers, currentPage, hasMore, isLoadingMore, maxTotalItems];
}

class TeacherLoaded extends TeacherState {
  final TeacherModel teacher;

  const TeacherLoaded(this.teacher);

  @override
  List<Object?> get props => [teacher];
}

class TeacherOperationSuccess extends TeacherState {
  final String message;

  const TeacherOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class TeacherError extends TeacherState {
  final String message;

  const TeacherError(this.message);

  @override
  List<Object?> get props => [message];
}

