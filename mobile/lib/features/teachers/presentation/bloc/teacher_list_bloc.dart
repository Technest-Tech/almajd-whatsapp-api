import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';


import '../../data/models/teacher_model.dart';
import '../../data/teacher_repository.dart';

// ── Events ──────────────────────────────────────────

abstract class TeacherListEvent extends Equatable {
  const TeacherListEvent();
  @override
  List<Object?> get props => [];
}

class TeacherListFetchRequested extends TeacherListEvent {
  final String? search;
  final bool refresh;

  const TeacherListFetchRequested({this.search, this.refresh = false});

  @override
  List<Object?> get props => [search, refresh];
}

class TeacherListRefreshRequested extends TeacherListEvent {}

class TeacherListSearchChanged extends TeacherListEvent {
  final String query;
  const TeacherListSearchChanged(this.query);

  @override
  List<Object?> get props => [query];
}

class TeacherDeleteRequested extends TeacherListEvent {
  final int teacherId;
  const TeacherDeleteRequested(this.teacherId);

  @override
  List<Object?> get props => [teacherId];
}

// ── States ──────────────────────────────────────────

abstract class TeacherListState extends Equatable {
  const TeacherListState();
  @override
  List<Object?> get props => [];
}

class TeacherListInitial extends TeacherListState {}

class TeacherListLoading extends TeacherListState {}

class TeacherListLoaded extends TeacherListState {
  final List<TeacherModel> teachers;
  final String searchQuery;

  const TeacherListLoaded({
    required this.teachers,
    this.searchQuery = '',
  });

  @override
  List<Object?> get props => [teachers, searchQuery];
}

class TeacherListError extends TeacherListState {
  final String message;
  const TeacherListError(this.message);

  @override
  List<Object?> get props => [message];
}

// ── BLoC ──────────────────────────────────────────

class TeacherListBloc extends Bloc<TeacherListEvent, TeacherListState> {
  final TeacherRepository teacherRepository;

  TeacherListBloc({required this.teacherRepository}) : super(TeacherListInitial()) {
    on<TeacherListFetchRequested>(_onFetch);
    on<TeacherListRefreshRequested>(_onRefresh);
    on<TeacherListSearchChanged>(_onSearchChanged);
    on<TeacherDeleteRequested>(_onDelete);
  }

  String _currentSearch = '';

  Future<void> _onFetch(TeacherListFetchRequested event, Emitter<TeacherListState> emit) async {
    if (!event.refresh) emit(TeacherListLoading());

    final search = event.search ?? _currentSearch;
    _currentSearch = search;

    try {
      final teachers = await teacherRepository.getTeachers(
        search: search.isNotEmpty ? search : null,
      );
      emit(TeacherListLoaded(teachers: teachers, searchQuery: search));
    } catch (e) {
      emit(const TeacherListError('فشل تحميل المعلمين'));
    }
  }

  Future<void> _onRefresh(TeacherListRefreshRequested event, Emitter<TeacherListState> emit) async {
    add(TeacherListFetchRequested(search: _currentSearch, refresh: true));
  }

  Future<void> _onSearchChanged(TeacherListSearchChanged event, Emitter<TeacherListState> emit) async {
    _currentSearch = event.query;
    add(TeacherListFetchRequested(search: event.query));
  }

  Future<void> _onDelete(TeacherDeleteRequested event, Emitter<TeacherListState> emit) async {
    try {
      await teacherRepository.deleteTeacher(event.teacherId);
      add(TeacherListRefreshRequested());
    } catch (_) {}
  }
}
