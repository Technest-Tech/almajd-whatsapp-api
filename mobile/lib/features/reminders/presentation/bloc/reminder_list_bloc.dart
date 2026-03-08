import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/models/reminder_model.dart';
import '../../data/reminder_repository.dart';

// ── Events ──────────────────────────────────────────

abstract class ReminderListEvent extends Equatable {
  const ReminderListEvent();
  @override
  List<Object?> get props => [];
}

class ReminderListFetchRequested extends ReminderListEvent {
  final bool refresh;
  const ReminderListFetchRequested({this.refresh = false});
  @override
  List<Object?> get props => [refresh];
}

class ReminderListRefreshRequested extends ReminderListEvent {}

class ReminderListFilterChanged extends ReminderListEvent {
  final String statusFilter;
  const ReminderListFilterChanged(this.statusFilter);
  @override
  List<Object?> get props => [statusFilter];
}

class ReminderListCancelRequested extends ReminderListEvent {
  final int reminderId;
  const ReminderListCancelRequested(this.reminderId);
  @override
  List<Object?> get props => [reminderId];
}

// ── States ──────────────────────────────────────────

abstract class ReminderListState extends Equatable {
  const ReminderListState();
  @override
  List<Object?> get props => [];
}

class ReminderListInitial extends ReminderListState {}
class ReminderListLoading extends ReminderListState {}

class ReminderListLoaded extends ReminderListState {
  final List<ReminderModel> reminders;
  final String activeFilter;

  const ReminderListLoaded({required this.reminders, this.activeFilter = 'all'});
  @override
  List<Object?> get props => [reminders, activeFilter];
}

class ReminderListError extends ReminderListState {
  final String message;
  const ReminderListError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── BLoC ────────────────────────────────────────────

class ReminderListBloc extends Bloc<ReminderListEvent, ReminderListState> {
  final ReminderRepository reminderRepository;
  String _currentFilter = 'all';

  ReminderListBloc({required this.reminderRepository}) : super(ReminderListInitial()) {
    on<ReminderListFetchRequested>(_onFetch);
    on<ReminderListRefreshRequested>((e, emit) => add(const ReminderListFetchRequested(refresh: true)));
    on<ReminderListFilterChanged>(_onFilterChanged);
    on<ReminderListCancelRequested>(_onCancel);
  }

  Future<void> _onFetch(ReminderListFetchRequested event, Emitter<ReminderListState> emit) async {
    if (!event.refresh) emit(ReminderListLoading());
    try {
      final reminders = await reminderRepository.getReminders(
        status: _currentFilter != 'all' ? _currentFilter : null,
      );
      emit(ReminderListLoaded(reminders: reminders, activeFilter: _currentFilter));
    } catch (e) {
      emit(const ReminderListError('فشل تحميل التنبيهات'));
    }
  }

  void _onFilterChanged(ReminderListFilterChanged event, Emitter<ReminderListState> emit) {
    _currentFilter = event.statusFilter;
    add(const ReminderListFetchRequested(refresh: true));
  }

  Future<void> _onCancel(ReminderListCancelRequested event, Emitter<ReminderListState> emit) async {
    try {
      await reminderRepository.cancelReminder(event.reminderId);
      add(const ReminderListFetchRequested(refresh: true));
    } catch (e) {
      emit(const ReminderListError('فشل إلغاء التنبيه'));
    }
  }
}
