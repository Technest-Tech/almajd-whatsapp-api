import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/student_repository.dart';
import 'student_event.dart';
import 'student_state.dart';

class StudentBloc extends Bloc<StudentEvent, StudentState> {
  final StudentRepository repository;

  StudentBloc(this.repository) : super(StudentInitial()) {
    on<LoadStudents>(_onLoadStudents);
    on<LoadMoreStudents>(_onLoadMoreStudents);
    on<LoadStudent>(_onLoadStudent);
    on<CreateStudent>(_onCreateStudent);
    on<UpdateStudent>(_onUpdateStudent);
    on<DeleteStudent>(_onDeleteStudent);
    on<BulkDeleteStudents>(_onBulkDeleteStudents);
  }

  Future<void> _onLoadStudents(
    LoadStudents event,
    Emitter<StudentState> emit,
  ) async {
    emit(StudentLoading());
    try {
      final result = await repository.getStudents(
        search: event.search,
        country: event.country,
        currency: event.currency,
        sortBy: event.sortBy,
        sortOrder: event.sortOrder,
        page: event.page,
        perPage: event.perPage,
      );
      // Check if we have more pages and haven't reached max total
      final hasMore = result.hasMore && result.data.length < 3000;
      emit(StudentsLoaded(
        students: result.data,
        currentPage: result.currentPage,
        hasMore: hasMore,
      ));
    } catch (e) {
      emit(StudentError(e.toString()));
    }
  }

  Future<void> _onLoadMoreStudents(
    LoadMoreStudents event,
    Emitter<StudentState> emit,
  ) async {
    final currentState = state;
    if (currentState is StudentsLoaded) {
      // Don't load more if already loading or no more pages or reached max
      if (currentState.isLoadingMore || 
          !currentState.hasMore || 
          currentState.students.length >= currentState.maxTotalItems) {
        return;
      }

      emit(currentState.copyWith(isLoadingMore: true));
      try {
        final result = await repository.getStudents(
          search: event.search,
          country: event.country,
          currency: event.currency,
          sortBy: event.sortBy,
          sortOrder: event.sortOrder,
          page: event.page,
        );

        // Append new students to existing list
        final allStudents = [...currentState.students, ...result.data];
        
        // Check if we have more pages and haven't reached max total
        final hasMore = result.hasMore && allStudents.length < currentState.maxTotalItems;
        
        emit(StudentsLoaded(
          students: allStudents,
          currentPage: result.currentPage,
          hasMore: hasMore,
          isLoadingMore: false,
          maxTotalItems: currentState.maxTotalItems,
        ));
      } catch (e) {
        emit(currentState.copyWith(isLoadingMore: false));
        emit(StudentError(e.toString()));
      }
    }
  }

  Future<void> _onLoadStudent(
    LoadStudent event,
    Emitter<StudentState> emit,
  ) async {
    emit(StudentLoading());
    try {
      final student = await repository.getStudent(event.id);
      emit(StudentLoaded(student));
    } catch (e) {
      emit(StudentError(e.toString()));
    }
  }

  Future<void> _onCreateStudent(
    CreateStudent event,
    Emitter<StudentState> emit,
  ) async {
    emit(StudentLoading());
    try {
      await repository.createStudent(event.student);
      emit(const StudentOperationSuccess('Student created successfully'));
      add(const LoadStudents());
    } catch (e) {
      emit(StudentError(e.toString()));
    }
  }

  Future<void> _onUpdateStudent(
    UpdateStudent event,
    Emitter<StudentState> emit,
  ) async {
    emit(StudentLoading());
    try {
      await repository.updateStudent(event.id, event.student);
      emit(const StudentOperationSuccess('Student updated successfully'));
      add(const LoadStudents());
    } catch (e) {
      emit(StudentError(e.toString()));
    }
  }

  Future<void> _onDeleteStudent(
    DeleteStudent event,
    Emitter<StudentState> emit,
  ) async {
    emit(StudentLoading());
    try {
      await repository.deleteStudent(event.id);
      emit(const StudentOperationSuccess('Student deleted successfully'));
      add(const LoadStudents());
    } catch (e) {
      emit(StudentError(e.toString()));
    }
  }

  Future<void> _onBulkDeleteStudents(
    BulkDeleteStudents event,
    Emitter<StudentState> emit,
  ) async {
    emit(StudentLoading());
    try {
      await repository.bulkDeleteStudents(event.ids);
      emit(const StudentOperationSuccess('Students deleted successfully'));
      add(const LoadStudents());
    } catch (e) {
      emit(StudentError(e.toString()));
    }
  }
}

