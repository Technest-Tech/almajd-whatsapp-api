import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
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
      if (AuthBloc.demoMode) {
        await Future.delayed(const Duration(milliseconds: 400));
        var teachers = _generateMockTeachers();

        if (search.isNotEmpty) {
          teachers = teachers
              .where((t) =>
                  t.name.contains(search) ||
                  t.subjects.any((s) => s.contains(search)) ||
                  (t.phone?.contains(search) ?? false))
              .toList();
        }

        emit(TeacherListLoaded(teachers: teachers, searchQuery: search));
        return;
      }

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
    if (AuthBloc.demoMode) {
      add(TeacherListRefreshRequested());
      return;
    }
    try {
      await teacherRepository.deleteTeacher(event.teacherId);
      add(TeacherListRefreshRequested());
    } catch (_) {}
  }

  // ── Mock Data ──────────────────────────────────────

  List<TeacherModel> _generateMockTeachers() {
    final now = DateTime.now();
    return [
      TeacherModel(
        id: 1,
        name: 'أ. عبدالرحمن المنصور',
        phone: '+966551112233',
        email: 'mansour@almajd.com',
        subjects: ['القرآن الكريم', 'التجويد'],
        availability: 'available',
        notes: 'معلم رئيسي لحلقات التحفيظ',
        createdAt: now.subtract(const Duration(days: 365)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      TeacherModel(
        id: 2,
        name: 'أ. فاطمة الزهراني',
        phone: '+966552223344',
        email: 'zahrani@almajd.com',
        subjects: ['الرياضيات', 'العلوم'],
        availability: 'available',
        createdAt: now.subtract(const Duration(days: 200)),
        updatedAt: now.subtract(const Duration(days: 3)),
      ),
      TeacherModel(
        id: 3,
        name: 'أ. محمد الغامدي',
        phone: '+966553334455',
        email: 'ghamdi@almajd.com',
        subjects: ['اللغة العربية', 'النحو والصرف'],
        availability: 'busy',
        notes: 'في إجازة حتى نهاية الأسبوع',
        createdAt: now.subtract(const Duration(days: 150)),
        updatedAt: now,
      ),
      TeacherModel(
        id: 4,
        name: 'أ. نورة السبيعي',
        phone: '+966554445566',
        email: 'subaie@almajd.com',
        subjects: ['اللغة الإنجليزية'],
        availability: 'available',
        createdAt: now.subtract(const Duration(days: 90)),
        updatedAt: now.subtract(const Duration(days: 5)),
      ),
      TeacherModel(
        id: 5,
        name: 'أ. خالد العمري',
        phone: '+966555556677',
        email: 'omari@almajd.com',
        subjects: ['الحاسب الآلي', 'البرمجة'],
        availability: 'offline',
        notes: 'يعمل عن بُعد',
        createdAt: now.subtract(const Duration(days: 60)),
        updatedAt: now.subtract(const Duration(hours: 12)),
      ),
    ];
  }
}
