import 'package:equatable/equatable.dart';
import '../../data/models/lesson_model.dart';

abstract class LessonEvent extends Equatable {
  const LessonEvent();

  @override
  List<Object?> get props => [];
}

class LoadLessons extends LessonEvent {
  final int? courseId;
  final int? year;
  final int? month;
  final String? status;

  const LoadLessons({
    this.courseId,
    this.year,
    this.month,
    this.status,
  });

  @override
  List<Object?> get props => [courseId, year, month, status];
}

class LoadLesson extends LessonEvent {
  final int id;

  const LoadLesson(this.id);

  @override
  List<Object?> get props => [id];
}

class CreateLesson extends LessonEvent {
  final LessonModel lesson;

  const CreateLesson(this.lesson);

  @override
  List<Object?> get props => [lesson];
}

class UpdateLesson extends LessonEvent {
  final int id;
  final LessonModel lesson;

  const UpdateLesson(this.id, this.lesson);

  @override
  List<Object?> get props => [id, lesson];
}

class DeleteLesson extends LessonEvent {
  final int id;

  const DeleteLesson(this.id);

  @override
  List<Object?> get props => [id];
}

