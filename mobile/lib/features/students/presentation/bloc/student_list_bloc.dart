import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
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
      if (AuthBloc.demoMode) {
        await Future.delayed(const Duration(milliseconds: 400));
        var students = _generateMockStudents();

        if (filter != 'all') {
          students = students.where((s) => s.status == filter).toList();
        }
        if (search.isNotEmpty) {
          students = students
              .where((s) =>
                  s.name.contains(search) ||
                  (s.phone?.contains(search) ?? false) ||
                  (s.guardianName?.contains(search) ?? false))
              .toList();
        }

        emit(StudentListLoaded(
          students: students,
          activeFilter: filter,
          searchQuery: search,
        ));
        return;
      }

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
    if (AuthBloc.demoMode) {
      // In demo mode, just refresh the list (mock data won't actually change)
      add(StudentListRefreshRequested());
      return;
    }
    try {
      await studentRepository.deleteStudent(event.studentId);
      add(StudentListRefreshRequested());
    } catch (_) {}
  }

  // ── Mock Data ──────────────────────────────────────

  List<StudentModel> _generateMockStudents() {
    final now = DateTime.now();
    return [
      StudentModel(
        id: 1,
        name: 'يوسف أحمد العلي',
        phone: '+966501112233',
        status: 'active',
        guardianName: 'أحمد العلي',
        guardianPhone: '+966501112200',
        guardianRelation: 'أب',
        enrollmentDate: now.subtract(const Duration(days: 180)),
        notes: 'طالب متميز في القرآن الكريم',
        createdAt: now.subtract(const Duration(days: 180)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      StudentModel(
        id: 2,
        name: 'سارة محمد القحطاني',
        phone: '+966502223344',
        status: 'active',
        guardianName: 'محمد القحطاني',
        guardianPhone: '+966502223300',
        guardianRelation: 'أب',
        enrollmentDate: now.subtract(const Duration(days: 120)),
        createdAt: now.subtract(const Duration(days: 120)),
        updatedAt: now.subtract(const Duration(days: 5)),
      ),
      StudentModel(
        id: 3,
        name: 'عبدالله خالد السعيد',
        phone: '+966503334455',
        status: 'active',
        guardianName: 'خالد السعيد',
        guardianPhone: '+966503334400',
        guardianRelation: 'أب',
        enrollmentDate: now.subtract(const Duration(days: 90)),
        notes: 'يحتاج متابعة في الرياضيات',
        createdAt: now.subtract(const Duration(days: 90)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      StudentModel(
        id: 4,
        name: 'لمى عبدالرحمن الدوسري',
        phone: '+966504445566',
        status: 'inactive',
        guardianName: 'نورة القحطاني',
        guardianPhone: '+966504445500',
        guardianRelation: 'أم',
        enrollmentDate: now.subtract(const Duration(days: 365)),
        notes: 'انسحبت مؤقتاً',
        createdAt: now.subtract(const Duration(days: 365)),
        updatedAt: now.subtract(const Duration(days: 30)),
      ),
      StudentModel(
        id: 5,
        name: 'ريان أحمد الشمري',
        phone: '+966505556677',
        status: 'active',
        guardianName: 'أحمد الشمري',
        guardianPhone: '+966505556600',
        guardianRelation: 'أب',
        enrollmentDate: now.subtract(const Duration(days: 60)),
        createdAt: now.subtract(const Duration(days: 60)),
        updatedAt: now.subtract(const Duration(days: 3)),
      ),
      StudentModel(
        id: 6,
        name: 'عمر هشام الحربي',
        phone: '+966506667788',
        status: 'suspended',
        guardianName: 'هند الدوسري',
        guardianPhone: '+966506667700',
        guardianRelation: 'أم',
        enrollmentDate: now.subtract(const Duration(days: 200)),
        notes: 'موقوف بسبب عدم السداد',
        createdAt: now.subtract(const Duration(days: 200)),
        updatedAt: now.subtract(const Duration(days: 7)),
      ),
      StudentModel(
        id: 7,
        name: 'نوف سعد المالكي',
        phone: '+966507778899',
        status: 'active',
        guardianName: 'سعد المالكي',
        guardianPhone: '+966507778800',
        guardianRelation: 'أب',
        enrollmentDate: now.subtract(const Duration(days: 45)),
        createdAt: now.subtract(const Duration(days: 45)),
        updatedAt: now,
      ),
      StudentModel(
        id: 8,
        name: 'فيصل ناصر العتيبي',
        phone: '+966508889900',
        status: 'active',
        guardianName: 'ناصر العتيبي',
        guardianPhone: '+966508889900',
        guardianRelation: 'أب',
        enrollmentDate: now.subtract(const Duration(days: 30)),
        notes: 'مسجل في دورة التجويد',
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(hours: 6)),
      ),
    ];
  }
}
