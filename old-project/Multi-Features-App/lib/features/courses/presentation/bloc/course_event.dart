import 'package:equatable/equatable.dart';
import '../../data/models/course_model.dart';

abstract class CourseEvent extends Equatable {
  const CourseEvent();

  @override
  List<Object?> get props => [];
}

class LoadCourses extends CourseEvent {
  final int? studentId;
  final int? teacherId;
  final String? search;

  const LoadCourses({
    this.studentId,
    this.teacherId,
    this.search,
  });

  @override
  List<Object?> get props => [studentId, teacherId, search];
}

class LoadCourse extends CourseEvent {
  final int id;

  const LoadCourse(this.id);

  @override
  List<Object?> get props => [id];
}

class CreateCourse extends CourseEvent {
  final CourseModel course;

  const CreateCourse(this.course);

  @override
  List<Object?> get props => [course];
}

class UpdateCourse extends CourseEvent {
  final int id;
  final CourseModel course;

  const UpdateCourse(this.id, this.course);

  @override
  List<Object?> get props => [id, course];
}

class DeleteCourse extends CourseEvent {
  final int id;

  const DeleteCourse(this.id);

  @override
  List<Object?> get props => [id];
}

