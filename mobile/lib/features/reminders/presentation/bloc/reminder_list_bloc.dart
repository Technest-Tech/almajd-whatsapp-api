import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
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
      if (AuthBloc.demoMode) {
        await Future.delayed(const Duration(milliseconds: 400));
        final all = _generateMock();
        final filtered = _currentFilter == 'all' ? all : all.where((r) => r.status == _currentFilter).toList();
        emit(ReminderListLoaded(reminders: filtered, activeFilter: _currentFilter));
        return;
      }
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
      if (!AuthBloc.demoMode) {
        await reminderRepository.cancelReminder(event.reminderId);
      }
      add(const ReminderListFetchRequested(refresh: true));
    } catch (e) {
      emit(const ReminderListError('فشل إلغاء التنبيه'));
    }
  }

  List<ReminderModel> _generateMock() {
    final now = DateTime.now();
    return [
      ReminderModel(id: 1, type: 'session_reminder', recipientPhone: '0501234567', recipientName: 'أحمد بن محمد', messageBody: 'تذكير: حصة القرآن الكريم غداً الساعة 8:00 صباحاً', scheduledAt: now.add(const Duration(hours: 12)), status: 'pending', createdAt: now),
      ReminderModel(id: 2, type: 'guardian_notification', recipientPhone: '0559876543', recipientName: 'سارة بنت عبدالله', messageBody: 'إشعار: ابنكم أتم حفظ الجزء الثالث بنجاح', scheduledAt: now.add(const Duration(hours: 6)), status: 'pending', createdAt: now),
      ReminderModel(id: 3, type: 'session_reminder', recipientPhone: '0507654321', recipientName: 'خالد بن سعد', messageBody: 'تذكير: حصة الرياضيات غداً الساعة 9:30 صباحاً', scheduledAt: now.subtract(const Duration(hours: 2)), sentAt: now.subtract(const Duration(hours: 1)), status: 'sent', createdAt: now.subtract(const Duration(hours: 3))),
      ReminderModel(id: 4, type: 'custom', recipientPhone: '0512345678', recipientName: 'عبدالرحمن العتيبي', messageBody: 'يرجى الحضور لتسليم الكتب الدراسية يوم الأحد', scheduledAt: now.subtract(const Duration(days: 1)), sentAt: now.subtract(const Duration(hours: 20)), status: 'sent', createdAt: now.subtract(const Duration(days: 2))),
      ReminderModel(id: 5, type: 'session_reminder', recipientPhone: '0531112222', recipientName: 'فهد المالكي', messageBody: 'تذكير: حصة العلوم', scheduledAt: now.subtract(const Duration(hours: 5)), status: 'failed', failureReason: 'رقم غير صحيح', createdAt: now.subtract(const Duration(hours: 6))),
      ReminderModel(id: 6, type: 'guardian_notification', recipientPhone: '0543334444', recipientName: 'نورة الشمري', messageBody: 'إشعار: تم تسجيل غياب ابنكم اليوم', scheduledAt: now.subtract(const Duration(hours: 8)), status: 'cancelled', createdAt: now.subtract(const Duration(hours: 10))),
      ReminderModel(id: 7, type: 'session_reminder', recipientPhone: '0555556666', recipientName: 'محمد الحربي', messageBody: 'تذكير: حصة التجويد غداً الساعة 8:00 صباحاً', scheduledAt: now.add(const Duration(days: 1)), status: 'pending', createdAt: now),
      ReminderModel(id: 8, type: 'custom', recipientPhone: '0567778888', recipientName: 'سلطان القحطاني', messageBody: 'دعوة لحضور حفل تكريم الطلاب المتفوقين', scheduledAt: now.subtract(const Duration(days: 2)), sentAt: now.subtract(const Duration(days: 2)), status: 'sent', createdAt: now.subtract(const Duration(days: 3))),
    ];
  }
}
