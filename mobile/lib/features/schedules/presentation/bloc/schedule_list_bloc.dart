import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
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
      if (AuthBloc.demoMode) {
        await Future.delayed(const Duration(milliseconds: 400));
        final all = _generateMockSchedules();
        final filtered = _applyFilters(all);
        emit(ScheduleListLoaded(
          schedules: filtered,
          activeFilter: _currentFilter,
          searchQuery: _currentSearch,
        ));
        return;
      }

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
      if (!AuthBloc.demoMode) {
        await scheduleRepository.deleteSchedule(event.scheduleId);
      }
      add(const ScheduleListFetchRequested(refresh: true));
    } catch (e) {
      emit(const ScheduleListError('فشل حذف الجدول'));
    }
  }

  List<ScheduleModel> _applyFilters(List<ScheduleModel> schedules) {
    var result = schedules;

    if (_currentFilter == 'active') {
      result = result.where((s) => s.isActive).toList();
    } else if (_currentFilter == 'inactive') {
      result = result.where((s) => !s.isActive).toList();
    }

    if (_currentSearch.isNotEmpty) {
      final q = _currentSearch.toLowerCase();
      result = result.where((s) =>
          s.name.toLowerCase().contains(q) ||
          (s.description ?? '').toLowerCase().contains(q)).toList();
    }

    return result;
  }

  List<ScheduleModel> _generateMockSchedules() {
    final now = DateTime.now();
    return [
      ScheduleModel(
        id: 1,
        name: 'جدول الفصل الدراسي الأول',
        description: 'الجدول الأساسي للفصل الدراسي الأول 1446هـ',
        startDate: DateTime(now.year, 9, 1),
        endDate: DateTime(now.year, 12, 30),
        isActive: true,
        entries: [
          ScheduleEntryModel(id: 1, scheduleId: 1, teacherName: 'أ. عبدالله المحمد', title: 'القرآن الكريم', dayOfWeek: 0, startTime: '08:00', endTime: '09:00', recurrence: 'weekly'),
          ScheduleEntryModel(id: 2, scheduleId: 1, teacherName: 'أ. فاطمة الأحمد', title: 'الرياضيات', dayOfWeek: 0, startTime: '09:30', endTime: '10:30', recurrence: 'weekly'),
          ScheduleEntryModel(id: 3, scheduleId: 1, teacherName: 'أ. خالد العتيبي', title: 'اللغة العربية', dayOfWeek: 1, startTime: '08:00', endTime: '09:00', recurrence: 'weekly'),
          ScheduleEntryModel(id: 4, scheduleId: 1, teacherName: 'أ. نورة السعيد', title: 'العلوم', dayOfWeek: 2, startTime: '10:00', endTime: '11:00', recurrence: 'weekly'),
          ScheduleEntryModel(id: 5, scheduleId: 1, teacherName: 'أ. عبدالله المحمد', title: 'التجويد', dayOfWeek: 3, startTime: '08:00', endTime: '09:00', recurrence: 'weekly'),
        ],
        createdAt: now.subtract(const Duration(days: 90)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      ScheduleModel(
        id: 2,
        name: 'جدول حلقة التحفيظ المسائية',
        description: 'حلقة التحفيظ المسائية للطلاب المتفوقين',
        startDate: DateTime(now.year, 9, 15),
        endDate: DateTime(now.year + 1, 1, 15),
        isActive: true,
        entries: [
          ScheduleEntryModel(id: 6, scheduleId: 2, teacherName: 'أ. عبدالله المحمد', title: 'حفظ القرآن', dayOfWeek: 0, startTime: '16:00', endTime: '17:30', recurrence: 'weekly'),
          ScheduleEntryModel(id: 7, scheduleId: 2, teacherName: 'أ. عبدالله المحمد', title: 'مراجعة الحفظ', dayOfWeek: 2, startTime: '16:00', endTime: '17:30', recurrence: 'weekly'),
          ScheduleEntryModel(id: 8, scheduleId: 2, teacherName: 'أ. عبدالله المحمد', title: 'تسميع الحفظ', dayOfWeek: 4, startTime: '16:00', endTime: '17:30', recurrence: 'weekly'),
        ],
        createdAt: now.subtract(const Duration(days: 80)),
        updatedAt: now.subtract(const Duration(days: 5)),
      ),
      ScheduleModel(
        id: 3,
        name: 'الدورة الصيفية المكثفة',
        description: 'دورة صيفية مكثفة لتأسيس الطلاب في اللغة العربية',
        startDate: DateTime(now.year, 6, 1),
        endDate: DateTime(now.year, 8, 31),
        isActive: false,
        entries: [
          ScheduleEntryModel(id: 9, scheduleId: 3, teacherName: 'أ. خالد العتيبي', title: 'نحو وصرف', dayOfWeek: 0, startTime: '09:00', endTime: '11:00', recurrence: 'weekly'),
          ScheduleEntryModel(id: 10, scheduleId: 3, teacherName: 'أ. خالد العتيبي', title: 'إملاء وتعبير', dayOfWeek: 2, startTime: '09:00', endTime: '11:00', recurrence: 'weekly'),
        ],
        createdAt: now.subtract(const Duration(days: 200)),
        updatedAt: now.subtract(const Duration(days: 45)),
      ),
      ScheduleModel(
        id: 4,
        name: 'برنامج التقوية في الرياضيات',
        description: 'برنامج أسبوعي لتقوية الطلاب الضعاف في الرياضيات',
        startDate: DateTime(now.year, 10, 1),
        endDate: DateTime(now.year, 12, 15),
        isActive: true,
        entries: [
          ScheduleEntryModel(id: 11, scheduleId: 4, teacherName: 'أ. فاطمة الأحمد', title: 'تقوية رياضيات', dayOfWeek: 1, startTime: '14:00', endTime: '15:30', recurrence: 'weekly'),
          ScheduleEntryModel(id: 12, scheduleId: 4, teacherName: 'أ. فاطمة الأحمد', title: 'تمارين تطبيقية', dayOfWeek: 3, startTime: '14:00', endTime: '15:30', recurrence: 'biweekly'),
        ],
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 3)),
      ),
    ];
  }
}
