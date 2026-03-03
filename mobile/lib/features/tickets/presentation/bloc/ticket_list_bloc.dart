import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/ticket_model.dart';
import '../../data/ticket_repository.dart';

// ── Events ──────────────────────────────────────────

abstract class TicketListEvent extends Equatable {
  const TicketListEvent();
  @override
  List<Object?> get props => [];
}

class TicketListFetchRequested extends TicketListEvent {
  final String? statusFilter;
  final bool refresh;

  const TicketListFetchRequested({this.statusFilter, this.refresh = false});

  @override
  List<Object?> get props => [statusFilter, refresh];
}

class TicketListRefreshRequested extends TicketListEvent {}

class TicketListFilterChanged extends TicketListEvent {
  final String status;
  const TicketListFilterChanged(this.status);

  @override
  List<Object?> get props => [status];
}

class TicketQuickAssign extends TicketListEvent {
  final int ticketId;
  final int userId;
  const TicketQuickAssign({required this.ticketId, required this.userId});

  @override
  List<Object?> get props => [ticketId, userId];
}

class TicketQuickStatusChange extends TicketListEvent {
  final int ticketId;
  final String status;
  const TicketQuickStatusChange({required this.ticketId, required this.status});

  @override
  List<Object?> get props => [ticketId, status];
}

// ── States ──────────────────────────────────────────

abstract class TicketListState extends Equatable {
  const TicketListState();
  @override
  List<Object?> get props => [];
}

class TicketListInitial extends TicketListState {}

class TicketListLoading extends TicketListState {}

class TicketListLoaded extends TicketListState {
  final List<TicketModel> tickets;
  final String activeFilter;
  final Map<String, dynamic>? stats;

  const TicketListLoaded({
    required this.tickets,
    this.activeFilter = 'all',
    this.stats,
  });

  @override
  List<Object?> get props => [tickets, activeFilter, stats];
}

class TicketListError extends TicketListState {
  final String message;
  const TicketListError(this.message);

  @override
  List<Object?> get props => [message];
}

// ── BLoC ──────────────────────────────────────────

class TicketListBloc extends Bloc<TicketListEvent, TicketListState> {
  final TicketRepository ticketRepository;

  TicketListBloc({required this.ticketRepository}) : super(TicketListInitial()) {
    on<TicketListFetchRequested>(_onFetch);
    on<TicketListRefreshRequested>(_onRefresh);
    on<TicketListFilterChanged>(_onFilterChanged);
    on<TicketQuickAssign>(_onQuickAssign);
    on<TicketQuickStatusChange>(_onQuickStatusChange);
  }

  Future<void> _onFetch(TicketListFetchRequested event, Emitter<TicketListState> emit) async {
    if (!event.refresh) emit(TicketListLoading());
    try {
      // ── Demo Mode: return mock data without API call ──
      if (AuthBloc.demoMode) {
        await Future.delayed(const Duration(milliseconds: 400));
        final allTickets = _generateMockTickets();
        final filtered = (event.statusFilter == null || event.statusFilter == 'all')
            ? allTickets
            : allTickets.where((t) => t.status == event.statusFilter).toList();
        emit(TicketListLoaded(
          tickets: filtered,
          activeFilter: event.statusFilter ?? 'all',
          stats: _mockStats(allTickets),
        ));
        return;
      }

      final tickets = await ticketRepository.getTickets(
        status: event.statusFilter,
      );
      Map<String, dynamic>? stats;
      try {
        stats = await ticketRepository.getStats();
      } catch (_) {}
      emit(TicketListLoaded(
        tickets: tickets,
        activeFilter: event.statusFilter ?? 'all',
        stats: stats,
      ));
    } catch (e) {
      emit(const TicketListError('فشل تحميل التذاكر'));
    }
  }

  Future<void> _onRefresh(TicketListRefreshRequested event, Emitter<TicketListState> emit) async {
    final currentFilter = state is TicketListLoaded
        ? (state as TicketListLoaded).activeFilter
        : 'all';
    add(TicketListFetchRequested(statusFilter: currentFilter, refresh: true));
  }

  Future<void> _onFilterChanged(TicketListFilterChanged event, Emitter<TicketListState> emit) async {
    add(TicketListFetchRequested(statusFilter: event.status));
  }

  Future<void> _onQuickAssign(TicketQuickAssign event, Emitter<TicketListState> emit) async {
    if (AuthBloc.demoMode) return;
    try {
      await ticketRepository.assignTicket(event.ticketId, event.userId);
      add(TicketListRefreshRequested());
    } catch (_) {}
  }

  Future<void> _onQuickStatusChange(TicketQuickStatusChange event, Emitter<TicketListState> emit) async {
    if (AuthBloc.demoMode) return;
    try {
      await ticketRepository.updateStatus(event.ticketId, event.status);
      add(TicketListRefreshRequested());
    } catch (_) {}
  }

  // ── Mock Data Helpers ──────────────────────────────

  List<TicketModel> _generateMockTickets() {
    final now = DateTime.now();
    return [
      TicketModel(
        id: 1,
        ticketNumber: '#TK-1001',
        status: 'open',
        priority: 'urgent',
        guardianName: 'فاطمة الزهراء',
        guardianPhone: '+966501112233',
        studentName: 'يوسف أحمد',
        lastMessage: 'السلام عليكم، أريد الاستفسار عن موعد الاختبار',
        unreadCount: 3,
        assignedToName: null,
        assignedToId: null,
        createdAt: now.subtract(const Duration(minutes: 15)),
        updatedAt: now.subtract(const Duration(minutes: 5)),
        slaDeadline: now.add(const Duration(hours: 3, minutes: 45)),
        tags: ['استفسار', 'اختبارات'],
      ),
      TicketModel(
        id: 2,
        ticketNumber: '#TK-1002',
        status: 'assigned',
        priority: 'high',
        guardianName: 'محمد العلي',
        guardianPhone: '+966502223344',
        studentName: 'سارة محمد',
        lastMessage: 'ابنتي لم تحضر الحصة اليوم بسبب المرض',
        unreadCount: 1,
        assignedToName: 'أحمد المشرف',
        assignedToId: 1,
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(minutes: 30)),
        slaDeadline: now.add(const Duration(hours: 1, minutes: 15)),
        tags: ['غياب', 'عذر طبي'],
      ),
      TicketModel(
        id: 3,
        ticketNumber: '#TK-1003',
        status: 'pending',
        priority: 'normal',
        guardianName: 'خالد السعيد',
        guardianPhone: '+966503334455',
        studentName: 'عبدالله خالد',
        lastMessage: 'هل يمكن تغيير موعد حصة الرياضيات؟',
        unreadCount: 0,
        assignedToName: 'أحمد المشرف',
        assignedToId: 1,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 4)),
        slaDeadline: now.add(const Duration(minutes: 20)),
        tags: ['جدول', 'تغيير موعد'],
      ),
      TicketModel(
        id: 4,
        ticketNumber: '#TK-1004',
        status: 'escalated',
        priority: 'urgent',
        guardianName: 'نورة القحطاني',
        guardianPhone: '+966504445566',
        studentName: 'لمى عبدالرحمن',
        lastMessage: 'المشكلة لم تُحل منذ أسبوع!',
        unreadCount: 5,
        assignedToName: 'سعد المشرف الأول',
        assignedToId: 2,
        createdAt: now.subtract(const Duration(days: 7)),
        updatedAt: now.subtract(const Duration(hours: 1)),
        slaDeadline: now.subtract(const Duration(hours: 2)),
        tags: ['شكوى', 'متصاعد'],
      ),
      TicketModel(
        id: 5,
        ticketNumber: '#TK-1005',
        status: 'resolved',
        priority: 'low',
        guardianName: 'أحمد الشمري',
        guardianPhone: '+966505556677',
        studentName: 'ريان أحمد',
        lastMessage: 'شكراً لكم، تم حل المشكلة',
        unreadCount: 0,
        assignedToName: 'أحمد المشرف',
        assignedToId: 1,
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 1)),
        slaDeadline: now.add(const Duration(days: 2)),
        tags: ['محلول'],
      ),
      TicketModel(
        id: 6,
        ticketNumber: '#TK-1006',
        status: 'open',
        priority: 'high',
        guardianName: 'هند الدوسري',
        guardianPhone: '+966506667788',
        studentName: 'عمر هشام',
        lastMessage: 'أريد التسجيل في دورة القرآن الكريم',
        unreadCount: 2,
        assignedToName: null,
        assignedToId: null,
        createdAt: now.subtract(const Duration(hours: 1)),
        updatedAt: now.subtract(const Duration(minutes: 10)),
        slaDeadline: now.add(const Duration(hours: 5)),
        tags: ['تسجيل', 'قرآن'],
      ),
    ];
  }

  Map<String, dynamic> _mockStats(List<TicketModel> tickets) {
    return {
      'open': tickets.where((t) => t.status == 'open').length,
      'assigned': tickets.where((t) => t.status == 'assigned').length,
      'pending': tickets.where((t) => t.status == 'pending').length,
      'escalated': tickets.where((t) => t.status == 'escalated').length,
      'resolved': tickets.where((t) => t.status == 'resolved').length,
      'closed': tickets.where((t) => t.status == 'closed').length,
      'total': tickets.length,
    };
  }
}
