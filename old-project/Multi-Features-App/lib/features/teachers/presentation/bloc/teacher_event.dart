import 'package:equatable/equatable.dart';
import '../../data/models/teacher_model.dart';

abstract class TeacherEvent extends Equatable {
  const TeacherEvent();

  @override
  List<Object?> get props => [];
}

class LoadTeachers extends TeacherEvent {
  final String? search;
  final int page;

  const LoadTeachers({this.search, this.page = 1});

  @override
  List<Object?> get props => [search, page];
}

class LoadMoreTeachers extends TeacherEvent {
  final String? search;
  final int page;

  const LoadMoreTeachers({this.search, required this.page});

  @override
  List<Object?> get props => [search, page];
}

class LoadTeacher extends TeacherEvent {
  final int id;

  const LoadTeacher(this.id);

  @override
  List<Object?> get props => [id];
}

class CreateTeacher extends TeacherEvent {
  final TeacherModel teacher;
  final String password;

  const CreateTeacher(this.teacher, this.password);

  @override
  List<Object?> get props => [teacher, password];
}

class UpdateTeacher extends TeacherEvent {
  final int id;
  final TeacherModel teacher;
  final String? password;

  const UpdateTeacher(this.id, this.teacher, this.password);

  @override
  List<Object?> get props => [id, teacher, password];
}

class DeleteTeacher extends TeacherEvent {
  final int id;

  const DeleteTeacher(this.id);

  @override
  List<Object?> get props => [id];
}

