import 'package:equatable/equatable.dart';
import '../../data/models/student_model.dart';

abstract class StudentEvent extends Equatable {
  const StudentEvent();

  @override
  List<Object?> get props => [];
}

class LoadStudents extends StudentEvent {
  final String? search;
  final String? country;
  final String? currency;
  final String? sortBy;
  final String? sortOrder;
  final int page;
  final int? perPage;

  const LoadStudents({
    this.search,
    this.country,
    this.currency,
    this.sortBy,
    this.sortOrder,
    this.page = 1,
    this.perPage,
  });

  @override
  List<Object?> get props => [search, country, currency, sortBy, sortOrder, page, perPage];
}

class LoadMoreStudents extends StudentEvent {
  final String? search;
  final String? country;
  final String? currency;
  final String? sortBy;
  final String? sortOrder;
  final int page;

  const LoadMoreStudents({
    this.search,
    this.country,
    this.currency,
    this.sortBy,
    this.sortOrder,
    required this.page,
  });

  @override
  List<Object?> get props => [search, country, currency, sortBy, sortOrder, page];
}

class LoadStudent extends StudentEvent {
  final int id;

  const LoadStudent(this.id);

  @override
  List<Object?> get props => [id];
}

class CreateStudent extends StudentEvent {
  final StudentModel student;

  const CreateStudent(this.student);

  @override
  List<Object?> get props => [student];
}

class UpdateStudent extends StudentEvent {
  final int id;
  final StudentModel student;

  const UpdateStudent(this.id, this.student);

  @override
  List<Object?> get props => [id, student];
}

class DeleteStudent extends StudentEvent {
  final int id;

  const DeleteStudent(this.id);

  @override
  List<Object?> get props => [id];
}

class BulkDeleteStudents extends StudentEvent {
  final List<int> ids;

  const BulkDeleteStudents(this.ids);

  @override
  List<Object?> get props => [ids];
}

