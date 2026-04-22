import 'package:equatable/equatable.dart';
import '../../data/models/course_model.dart';

abstract class CourseState extends Equatable {
  const CourseState();

  @override
  List<Object?> get props => [];
}

class CourseInitial extends CourseState {}

class CourseLoading extends CourseState {}

class CoursesLoaded extends CourseState {
  final List<CourseModel> courses;

  const CoursesLoaded(this.courses);

  @override
  List<Object?> get props => [courses];
}

class CourseLoaded extends CourseState {
  final CourseModel course;

  const CourseLoaded(this.course);

  @override
  List<Object?> get props => [course];
}

class CourseOperationSuccess extends CourseState {
  final String message;

  const CourseOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class CourseError extends CourseState {
  final String message;

  const CourseError(this.message);

  @override
  List<Object?> get props => [message];
}

