import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
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
      if (AuthBloc.demoMode) {
        await Future.delayed(const Duration(milliseconds: 400));
        final all = _generateMockSessions();
        final filtered = _currentFilter == 'all'
            ? all
            : all.where((s) => s.status == _currentFilter).toList();
        emit(SessionListLoaded(sessions: filtered, activeFilter: _currentFilter));
        return;
      }

      final sessions = await sessionRepository.getSessions(
        status: _currentFilter != 'all' ? _currentFilter : null,
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
      if (!AuthBloc.demoMode) {
        await sessionRepository.updateStatus(event.sessionId, status: event.newStatus, reason: event.reason);
      }
      add(const SessionListFetchRequested(refresh: true));
    } catch (e) {
      emit(const SessionListError('فشل تحديث حالة الحصة'));
    }
  }

  List<SessionModel> _generateMockSessions() {
    final now = DateTime.now();
    return [
      SessionModel(id: 1, title: 'القرآن الكريم', teacherName: 'أ. عبدالله المحمد', sessionDate: now, startTime: '08:00', endTime: '09:00', status: 'scheduled', createdAt: now.subtract(const Duration(days: 1))),
      SessionModel(id: 2, title: 'الرياضيات', teacherName: 'أ. فاطمة الأحمد', sessionDate: now, startTime: '09:30', endTime: '10:30', status: 'scheduled', createdAt: now.subtract(const Duration(days: 1))),
      SessionModel(id: 3, title: 'القرآن الكريم', teacherName: 'أ. عبدالله المحمد', sessionDate: now.subtract(const Duration(days: 1)), startTime: '08:00', endTime: '09:00', status: 'completed', createdAt: now.subtract(const Duration(days: 2))),
      SessionModel(id: 4, title: 'اللغة العربية', teacherName: 'أ. خالد العتيبي', sessionDate: now.subtract(const Duration(days: 1)), startTime: '09:30', endTime: '10:30', status: 'completed', createdAt: now.subtract(const Duration(days: 2))),
      SessionModel(id: 5, title: 'العلوم', teacherName: 'أ. نورة السعيد', sessionDate: now.subtract(const Duration(days: 2)), startTime: '10:00', endTime: '11:00', status: 'cancelled', cancellationReason: 'غياب المعلمة', createdAt: now.subtract(const Duration(days: 3))),
      SessionModel(id: 6, title: 'حفظ القرآن', teacherName: 'أ. عبدالله المحمد', sessionDate: now.subtract(const Duration(days: 2)), startTime: '16:00', endTime: '17:30', status: 'completed', createdAt: now.subtract(const Duration(days: 3))),
      SessionModel(id: 7, title: 'التجويد', teacherName: 'أ. عبدالله المحمد', sessionDate: now.add(const Duration(days: 1)), startTime: '08:00', endTime: '09:00', status: 'scheduled', createdAt: now),
      SessionModel(id: 8, title: 'تقوية رياضيات', teacherName: 'أ. فاطمة الأحمد', sessionDate: now.add(const Duration(days: 1)), startTime: '14:00', endTime: '15:30', status: 'scheduled', createdAt: now),
      SessionModel(id: 9, title: 'نحو وصرف', teacherName: 'أ. خالد العتيبي', sessionDate: now.subtract(const Duration(days: 3)), startTime: '09:00', endTime: '11:00', status: 'completed', createdAt: now.subtract(const Duration(days: 4))),
      SessionModel(id: 10, title: 'مراجعة الحفظ', teacherName: 'أ. عبدالله المحمد', sessionDate: now.subtract(const Duration(days: 4)), startTime: '16:00', endTime: '17:30', status: 'cancelled', cancellationReason: 'عطلة رسمية', createdAt: now.subtract(const Duration(days: 5))),
    ];
  }
}
