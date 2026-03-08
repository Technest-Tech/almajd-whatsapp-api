import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/models/schedule_model.dart';
import '../../data/schedule_repository.dart';

// ── Events ──────────────────────────────────────────

abstract class ScheduleListEvent extends Equatable {
  const ScheduleListEvent();
  @override
  List<Object?> get props => [];
}

class ScheduleListFetchRequested extends ScheduleListEvent {
  final bool refresh;
  const ScheduleListFetchRequested({this.refresh = false});
  @override
  List<Object?> get props => [refresh];
}

class ScheduleListRefreshRequested extends ScheduleListEvent {}

class ScheduleListSearchChanged extends ScheduleListEvent {
  final String query;
  const ScheduleListSearchChanged(this.query);
  @override
  List<Object?> get props => [query];
}

class ScheduleListFilterChanged extends ScheduleListEvent {
  final String filter; // 'all', 'active', 'inactive'
  const ScheduleListFilterChanged(this.filter);
  @override
  List<Object?> get props => [filter];
}

class ScheduleListDeleteRequested extends ScheduleListEvent {
  final int scheduleId;
  const ScheduleListDeleteRequested(this.scheduleId);
  @override
  List<Object?> get props => [scheduleId];
}

// ── States ──────────────────────────────────────────

abstract class ScheduleListState extends Equatable {
  const ScheduleListState();
  @override
  List<Object?> get props => [];
}

class ScheduleListInitial extends ScheduleListState {}

class ScheduleListLoading extends ScheduleListState {}

class ScheduleListLoaded extends ScheduleListState {
  final List<ScheduleModel> schedules;
  final String activeFilter;
  final String searchQuery;

  const ScheduleListLoaded({
    required this.schedules,
    this.activeFilter = 'all',
    this.searchQuery = '',
  });

  @override
  List<Object?> get props => [schedules, activeFilter, searchQuery];
}

class ScheduleListError extends ScheduleListState {
  final String message;
  const ScheduleListError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── BLoC ────────────────────────────────────────────

class ScheduleListBloc extends Bloc<ScheduleListEvent, ScheduleListState> {
  final ScheduleRepository scheduleRepository;

  String _currentFilter = 'all';
  String _currentSearch = '';

  ScheduleListBloc({required this.scheduleRepository}) : super(ScheduleListInitial()) {
    on<ScheduleListFetchRequested>(_onFetch);
    on<ScheduleListRefreshRequested>(
        (e, emit) => add(const ScheduleListFetchRequested(refresh: true)));
    on<ScheduleListSearchChanged>(_onSearchChanged);
    on<ScheduleListFilterChanged>(_onFilterChanged);
    on<ScheduleListDeleteRequested>(_onDelete);
  }

  Future<void> _onFetch(ScheduleListFetchRequested event, Emitter<ScheduleListState> emit) async {
    if (!event.refresh) emit(ScheduleListLoading());
    try {
      bool? isActive;
      if (_currentFilter == 'active') isActive = true;
      if (_currentFilter == 'inactive') isActive = false;

      final schedules = await scheduleRepository.getSchedules(
        isActive: isActive,
        search: _currentSearch.isNotEmpty ? _currentSearch : null,
      );
      emit(ScheduleListLoaded(
        schedules: schedules,
        activeFilter: _currentFilter,
        searchQuery: _currentSearch,
      ));
    } catch (e) {
      emit(const ScheduleListError('فشل تحميل الجداول'));
    }
  }

  void _onSearchChanged(ScheduleListSearchChanged event, Emitter<ScheduleListState> emit) {
    _currentSearch = event.query;
    add(const ScheduleListFetchRequested(refresh: true));
  }

  void _onFilterChanged(ScheduleListFilterChanged event, Emitter<ScheduleListState> emit) {
    _currentFilter = event.filter;
    add(const ScheduleListFetchRequested(refresh: true));
  }

  Future<void> _onDelete(ScheduleListDeleteRequested event, Emitter<ScheduleListState> emit) async {
    try {
      await scheduleRepository.deleteSchedule(event.scheduleId);
      add(const ScheduleListFetchRequested(refresh: true));
    } catch (e) {
      emit(const ScheduleListError('فشل حذف الجدول'));
    }
  }
}
