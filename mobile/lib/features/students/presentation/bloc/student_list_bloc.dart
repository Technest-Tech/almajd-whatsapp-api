import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/student_model.dart';
import '../../data/student_repository.dart';

// ── Events ──────────────────────────────────────────

abstract class StudentListEvent extends Equatable {
  const StudentListEvent();
  @override
  List<Object?> get props => [];
}

class StudentListFetchRequested extends StudentListEvent {
  final String? statusFilter;
  final String? search;
  final bool refresh;

  const StudentListFetchRequested({this.statusFilter, this.search, this.refresh = false});

  @override
  List<Object?> get props => [statusFilter, search, refresh];
}

class StudentListRefreshRequested extends StudentListEvent {}

class StudentListSearchChanged extends StudentListEvent {
  final String query;
  const StudentListSearchChanged(this.query);

  @override
  List<Object?> get props => [query];
}

class StudentListFilterChanged extends StudentListEvent {
  final String status;
  const StudentListFilterChanged(this.status);

  @override
  List<Object?> get props => [status];
}

class StudentDeleteRequested extends StudentListEvent {
  final int studentId;
  const StudentDeleteRequested(this.studentId);

  @override
  List<Object?> get props => [studentId];
}

// ── States ──────────────────────────────────────────

abstract class StudentListState extends Equatable {
  const StudentListState();
  @override
  List<Object?> get props => [];
}

class StudentListInitial extends StudentListState {}

class StudentListLoading extends StudentListState {}

class StudentListLoaded extends StudentListState {
  final List<StudentModel> students;
  final String activeFilter;
  final String searchQuery;

  const StudentListLoaded({
    required this.students,
    this.activeFilter = 'all',
    this.searchQuery = '',
  });

  @override
  List<Object?> get props => [students, activeFilter, searchQuery];
}

class StudentListError extends StudentListState {
  final String message;
  const StudentListError(this.message);

  @override
  List<Object?> get props => [message];
}

// ── BLoC ──────────────────────────────────────────

class StudentListBloc extends Bloc<StudentListEvent, StudentListState> {
  final StudentRepository studentRepository;

  StudentListBloc({required this.studentRepository}) : super(StudentListInitial()) {
    on<StudentListFetchRequested>(_onFetch);
    on<StudentListRefreshRequested>(_onRefresh);
    on<StudentListSearchChanged>(_onSearchChanged);
    on<StudentListFilterChanged>(_onFilterChanged);
    on<StudentDeleteRequested>(_onDelete);
  }

  String _currentSearch = '';
  String _currentFilter = 'all';

  Future<void> _onFetch(StudentListFetchRequested event, Emitter<StudentListState> emit) async {
    if (!event.refresh) emit(StudentListLoading());

    final search = event.search ?? _currentSearch;
    final filter = event.statusFilter ?? _currentFilter;
    _currentSearch = search;
    _currentFilter = filter;

    try {
      final students = await studentRepository.getStudents(
        search: search.isNotEmpty ? search : null,
        status: filter != 'all' ? filter : null,
      );
      emit(StudentListLoaded(
        students: students,
        activeFilter: filter,
        searchQuery: search,
      ));
    } catch (e) {
      emit(const StudentListError('فشل تحميل الطلاب'));
    }
  }

  Future<void> _onRefresh(StudentListRefreshRequested event, Emitter<StudentListState> emit) async {
    add(StudentListFetchRequested(
      statusFilter: _currentFilter,
      search: _currentSearch,
      refresh: true,
    ));
  }

  Future<void> _onSearchChanged(StudentListSearchChanged event, Emitter<StudentListState> emit) async {
    _currentSearch = event.query;
    add(StudentListFetchRequested(search: event.query, statusFilter: _currentFilter));
  }

  Future<void> _onFilterChanged(StudentListFilterChanged event, Emitter<StudentListState> emit) async {
    _currentFilter = event.status;
    add(StudentListFetchRequested(statusFilter: event.status, search: _currentSearch));
  }

  Future<void> _onDelete(StudentDeleteRequested event, Emitter<StudentListState> emit) async {
    try {
      await studentRepository.deleteStudent(event.studentId);
      add(StudentListRefreshRequested());
    } catch (_) {}
  }
}
