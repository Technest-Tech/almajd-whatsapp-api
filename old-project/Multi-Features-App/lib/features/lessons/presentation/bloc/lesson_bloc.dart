import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/lesson_repository.dart';
import 'lesson_event.dart';
import 'lesson_state.dart';

class LessonBloc extends Bloc<LessonEvent, LessonState> {
  final LessonRepository repository;

  LessonBloc(this.repository) : super(LessonInitial()) {
    on<LoadLessons>(_onLoadLessons);
    on<LoadLesson>(_onLoadLesson);
    on<CreateLesson>(_onCreateLesson);
    on<UpdateLesson>(_onUpdateLesson);
    on<DeleteLesson>(_onDeleteLesson);
  }

  Future<void> _onLoadLessons(
    LoadLessons event,
    Emitter<LessonState> emit,
  ) async {
    emit(LessonLoading());
    try {
      final lessons = await repository.getLessons(
        courseId: event.courseId,
        year: event.year,
        month: event.month,
        status: event.status,
      );
      emit(LessonsLoaded(lessons));
    } catch (e) {
      emit(LessonError(e.toString()));
    }
  }

  Future<void> _onLoadLesson(
    LoadLesson event,
    Emitter<LessonState> emit,
  ) async {
    emit(LessonLoading());
    try {
      final lesson = await repository.getLesson(event.id);
      emit(LessonLoaded(lesson));
    } catch (e) {
      emit(LessonError(e.toString()));
    }
  }

  Future<void> _onCreateLesson(
    CreateLesson event,
    Emitter<LessonState> emit,
  ) async {
    emit(LessonLoading());
    try {
      await repository.createLesson(event.lesson);
      emit(const LessonOperationSuccess('Lesson created successfully'));
      add(LoadLessons(
        courseId: event.lesson.courseId,
        year: event.lesson.date.year,
        month: event.lesson.date.month,
      ));
    } catch (e) {
      emit(LessonError(e.toString()));
    }
  }

  Future<void> _onUpdateLesson(
    UpdateLesson event,
    Emitter<LessonState> emit,
  ) async {
    emit(LessonLoading());
    try {
      await repository.updateLesson(event.id, event.lesson);
      emit(const LessonOperationSuccess('Lesson updated successfully'));
      add(LoadLessons(
        courseId: event.lesson.courseId,
        year: event.lesson.date.year,
        month: event.lesson.date.month,
      ));
    } catch (e) {
      emit(LessonError(e.toString()));
    }
  }

  Future<void> _onDeleteLesson(
    DeleteLesson event,
    Emitter<LessonState> emit,
  ) async {
    emit(LessonLoading());
    try {
      await repository.deleteLesson(event.id);
      emit(const LessonOperationSuccess('Lesson deleted successfully'));
      add(const LoadLessons());
    } catch (e) {
      emit(LessonError(e.toString()));
    }
  }
}

