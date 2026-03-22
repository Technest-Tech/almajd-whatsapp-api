import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/models/session_model.dart';
import '../../data/session_repository.dart';

// ── Events ──────────────────────────────────────────

abstract class SessionListEvent extends Equatable {
  const SessionListEvent();
  @override
  List<Object?> get props => [];
}

class SessionListFetchRequested extends SessionListEvent {
  final bool refresh;
  const SessionListFetchRequested({this.refresh = false});
  @override
  List<Object?> get props => [refresh];
}

class SessionListRefreshRequested extends SessionListEvent {}

class SessionListFilterChanged extends SessionListEvent {
  final String statusFilter; // 'all', 'scheduled', 'completed', 'cancelled'
  const SessionListFilterChanged(this.statusFilter);
  @override
  List<Object?> get props => [statusFilter];
}

class SessionListStatusUpdated extends SessionListEvent {
  final int sessionId;
  final String newStatus;
  final String? reason;
  const SessionListStatusUpdated(this.sessionId, this.newStatus, {this.reason});
  @override
  List<Object?> get props => [sessionId, newStatus, reason];
}

// ── States ──────────────────────────────────────────

abstract class SessionListState extends Equatable {
  const SessionListState();
  @override
  List<Object?> get props => [];
}

class SessionListInitial extends SessionListState {}

class SessionListLoading extends SessionListState {}

class SessionListLoaded extends SessionListState {
  final List<SessionModel> sessions;
  final String activeFilter;

  const SessionListLoaded({
    required this.sessions,
    this.activeFilter = 'all',
  });

  @override
  List<Object?> get props => [sessions, activeFilter];
}

class SessionListError extends SessionListState {
  final String message;
  const SessionListError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── BLoC ────────────────────────────────────────────

class SessionListBloc extends Bloc<SessionListEvent, SessionListState> {
  final SessionRepository sessionRepository;

  String _currentFilter = 'all';

  SessionListBloc({required this.sessionRepository}) : super(SessionListInitial()) {
    on<SessionListFetchRequested>(_onFetch);
    on<SessionListRefreshRequested>(
        (e, emit) => add(const SessionListFetchRequested(refresh: true)));
    on<SessionListFilterChanged>(_onFilterChanged);
    on<SessionListStatusUpdated>(_onStatusUpdated);
  }

  Future<void> _onFetch(SessionListFetchRequested event, Emitter<SessionListState> emit) async {
    if (!event.refresh) emit(SessionListLoading());
    try {
      final sessions = await sessionRepository.getSessions(
        status: _currentFilter != 'all' ? _currentFilter : null,
        perPage: 200,
      );
      emit(SessionListLoaded(sessions: sessions, activeFilter: _currentFilter));
    } catch (e) {
      emit(const SessionListError('فشل تحميل الحصص'));
    }
  }

  void _onFilterChanged(SessionListFilterChanged event, Emitter<SessionListState> emit) {
    _currentFilter = event.statusFilter;
    add(const SessionListFetchRequested(refresh: true));
  }

  Future<void> _onStatusUpdated(SessionListStatusUpdated event, Emitter<SessionListState> emit) async {
    try {
      await sessionRepository.updateStatus(event.sessionId, status: event.newStatus, reason: event.reason);
      add(const SessionListFetchRequested(refresh: true));
    } catch (e) {
      emit(const SessionListError('فشل تحديث حالة الحصة'));
    }
  }
}
