import 'package:equatable/equatable.dart';
import '../../data/models/lesson_model.dart';

abstract class LessonState extends Equatable {
  const LessonState();

  @override
  List<Object?> get props => [];
}

class LessonInitial extends LessonState {}

class LessonLoading extends LessonState {}

class LessonsLoaded extends LessonState {
  final List<LessonModel> lessons;

  const LessonsLoaded(this.lessons);

  @override
  List<Object?> get props => [lessons];
}

class LessonLoaded extends LessonState {
  final LessonModel lesson;

  const LessonLoaded(this.lesson);

  @override
  List<Object?> get props => [lesson];
}

class LessonOperationSuccess extends LessonState {
  final String message;

  const LessonOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class LessonError extends LessonState {
  final String message;

  const LessonError(this.message);

  @override
  List<Object?> get props => [message];
}

