import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/teacher_repository.dart';
import 'teacher_event.dart';
import 'teacher_state.dart';

class TeacherBloc extends Bloc<TeacherEvent, TeacherState> {
  final TeacherRepository repository;

  TeacherBloc(this.repository) : super(TeacherInitial()) {
    on<LoadTeachers>(_onLoadTeachers);
    on<LoadMoreTeachers>(_onLoadMoreTeachers);
    on<LoadTeacher>(_onLoadTeacher);
    on<CreateTeacher>(_onCreateTeacher);
    on<UpdateTeacher>(_onUpdateTeacher);
    on<DeleteTeacher>(_onDeleteTeacher);
  }

  Future<void> _onLoadTeachers(
    LoadTeachers event,
    Emitter<TeacherState> emit,
  ) async {
    emit(TeacherLoading());
    try {
      final result = await repository.getTeachers(search: event.search, page: event.page);
      // Check if we have more pages and haven't reached max total
      final hasMore = result.hasMore && result.data.length < 3000;
      emit(TeachersLoaded(
        teachers: result.data,
        currentPage: result.currentPage,
        hasMore: hasMore,
      ));
    } catch (e) {
      emit(TeacherError(e.toString()));
    }
  }

  Future<void> _onLoadMoreTeachers(
    LoadMoreTeachers event,
    Emitter<TeacherState> emit,
  ) async {
    final currentState = state;
    if (currentState is TeachersLoaded) {
      // Don't load more if already loading or no more pages or reached max
      if (currentState.isLoadingMore || 
          !currentState.hasMore || 
          currentState.teachers.length >= currentState.maxTotalItems) {
        return;
      }

      emit(currentState.copyWith(isLoadingMore: true));
      try {
        final result = await repository.getTeachers(search: event.search, page: event.page);

        // Append new teachers to existing list
        final allTeachers = [...currentState.teachers, ...result.data];
        
        // Check if we have more pages and haven't reached max total
        final hasMore = result.hasMore && allTeachers.length < currentState.maxTotalItems;
        
        emit(TeachersLoaded(
          teachers: allTeachers,
          currentPage: result.currentPage,
          hasMore: hasMore,
          isLoadingMore: false,
          maxTotalItems: currentState.maxTotalItems,
        ));
      } catch (e) {
        emit(currentState.copyWith(isLoadingMore: false));
        emit(TeacherError(e.toString()));
      }
    }
  }

  Future<void> _onLoadTeacher(
    LoadTeacher event,
    Emitter<TeacherState> emit,
  ) async {
    emit(TeacherLoading());
    try {
      final teacher = await repository.getTeacher(event.id);
      emit(TeacherLoaded(teacher));
    } catch (e) {
      emit(TeacherError(e.toString()));
    }
  }

  Future<void> _onCreateTeacher(
    CreateTeacher event,
    Emitter<TeacherState> emit,
  ) async {
    emit(TeacherLoading());
    try {
      await repository.createTeacher(event.teacher, event.password);
      emit(const TeacherOperationSuccess('Teacher created successfully'));
      add(const LoadTeachers(page: 1));
    } catch (e) {
      emit(TeacherError(e.toString()));
    }
  }

  Future<void> _onUpdateTeacher(
    UpdateTeacher event,
    Emitter<TeacherState> emit,
  ) async {
    emit(TeacherLoading());
    try {
      await repository.updateTeacher(event.id, event.teacher, event.password);
      emit(const TeacherOperationSuccess('Teacher updated successfully'));
      add(const LoadTeachers(page: 1));
    } catch (e) {
      emit(TeacherError(e.toString()));
    }
  }

  Future<void> _onDeleteTeacher(
    DeleteTeacher event,
    Emitter<TeacherState> emit,
  ) async {
    emit(TeacherLoading());
    try {
      await repository.deleteTeacher(event.id);
      emit(const TeacherOperationSuccess('Teacher deleted successfully'));
      add(const LoadTeachers(page: 1));
    } catch (e) {
      emit(TeacherError(e.toString()));
    }
  }
}

