import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/course_repository.dart';
import 'course_event.dart';
import 'course_state.dart';

class CourseBloc extends Bloc<CourseEvent, CourseState> {
  final CourseRepository repository;

  CourseBloc(this.repository) : super(CourseInitial()) {
    on<LoadCourses>(_onLoadCourses);
    on<LoadCourse>(_onLoadCourse);
    on<CreateCourse>(_onCreateCourse);
    on<UpdateCourse>(_onUpdateCourse);
    on<DeleteCourse>(_onDeleteCourse);
  }

  Future<void> _onLoadCourses(
    LoadCourses event,
    Emitter<CourseState> emit,
  ) async {
    emit(CourseLoading());
    try {
      final courses = await repository.getCourses(
        studentId: event.studentId,
        teacherId: event.teacherId,
        search: event.search,
      );
      emit(CoursesLoaded(courses));
    } catch (e) {
      emit(CourseError(e.toString()));
    }
  }

  Future<void> _onLoadCourse(
    LoadCourse event,
    Emitter<CourseState> emit,
  ) async {
    emit(CourseLoading());
    try {
      final course = await repository.getCourse(event.id);
      emit(CourseLoaded(course));
    } catch (e) {
      emit(CourseError(e.toString()));
    }
  }

  Future<void> _onCreateCourse(
    CreateCourse event,
    Emitter<CourseState> emit,
  ) async {
    emit(CourseLoading());
    try {
      await repository.createCourse(event.course);
      emit(const CourseOperationSuccess('Course created successfully'));
      add(LoadCourses());
    } catch (e) {
      emit(CourseError(e.toString()));
    }
  }

  Future<void> _onUpdateCourse(
    UpdateCourse event,
    Emitter<CourseState> emit,
  ) async {
    emit(CourseLoading());
    try {
      await repository.updateCourse(event.id, event.course);
      emit(const CourseOperationSuccess('Course updated successfully'));
      add(LoadCourses());
    } catch (e) {
      emit(CourseError(e.toString()));
    }
  }

  Future<void> _onDeleteCourse(
    DeleteCourse event,
    Emitter<CourseState> emit,
  ) async {
    emit(CourseLoading());
    try {
      await repository.deleteCourse(event.id);
      emit(const CourseOperationSuccess('Course deleted successfully'));
      add(LoadCourses());
    } catch (e) {
      emit(CourseError(e.toString()));
    }
  }
}

