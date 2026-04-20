import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';


import '../../data/models/ticket_model.dart';
import '../../data/ticket_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/api/websockets_client.dart';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import '../../../../core/api/api_client.dart';
import 'dart:convert';

// ── Events ──────────────────────────────────────────

abstract class TicketListEvent extends Equatable {
  const TicketListEvent();
  @override
  List<Object?> get props => [];
}

class TicketListFetchRequested extends TicketListEvent {
  final String? typeFilter;
  final bool refresh;
  final bool todaySessions;

  const TicketListFetchRequested({
    this.typeFilter,
    this.refresh = false,
    this.todaySessions = false,
  });

  @override
  List<Object?> get props => [typeFilter, refresh, todaySessions];
}

class TicketListRefreshRequested extends TicketListEvent {}

class TicketListFilterChanged extends TicketListEvent {
  final String status;
  final bool todaySessions;
  const TicketListFilterChanged(this.status, {this.todaySessions = false});

  @override
  List<Object?> get props => [status, todaySessions];
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

class TicketListSearchChanged extends TicketListEvent {
  final String query;
  const TicketListSearchChanged(this.query);

  @override
  List<Object?> get props => [query];
}

// Real-time: a new message arrived for a ticket in the list
class TicketListMessageReceived extends TicketListEvent {
  final int ticketId;
  final String messagePreview;
  const TicketListMessageReceived({
    required this.ticketId,
    required this.messagePreview,
  });

  @override
  List<Object?> get props => [ticketId, messagePreview];
}

// Delete a ticket
class TicketDeleteRequested extends TicketListEvent {
  final int ticketId;
  const TicketDeleteRequested(this.ticketId);

  @override
  List<Object?> get props => [ticketId];
}

// Mark ticket as read locally
class TicketReadStatusUpdated extends TicketListEvent {
  final int ticketId;
  const TicketReadStatusUpdated(this.ticketId);

  @override
  List<Object?> get props => [ticketId];
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
  final List<TicketModel> tickets;      // filtered list shown in UI
  final List<TicketModel> allTickets;  // full unfiltered list
  final String activeFilter;
  final String searchQuery;
  final Map<String, dynamic>? stats;
  final bool todaySessions;

  const TicketListLoaded({
    required this.tickets,
    required this.allTickets,
    this.activeFilter = 'all',
    this.searchQuery = '',
    this.stats,
    this.todaySessions = false,
  });

  @override
  List<Object?> get props => [tickets, allTickets, activeFilter, searchQuery, stats, todaySessions];
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
    on<TicketListSearchChanged>(_onSearch);
    on<TicketListMessageReceived>(_onMessageReceived);
    on<TicketDeleteRequested>(_onDelete);
    on<TicketReadStatusUpdated>(_onReadStatusUpdated);
  }

  bool _wsInitialized = false;

  void _setupWebsockets() async {
    if (_wsInitialized) return;
    _wsInitialized = true;

    print('[TicketListBloc] Setting up websockets...');

    final pusher = WebSocketsClient.instance.pusher;
    if (pusher == null) {
      print('[TicketListBloc] Pusher is null, will retry in 3s...');
      _wsInitialized = false;
      Future.delayed(const Duration(seconds: 3), () => _setupWebsockets());
      return;
    }

    final token = await const FlutterSecureStorage().read(key: 'access_token');
    if (token == null) {
      print('[TicketListBloc] No auth token, skipping websocket setup');
      _wsInitialized = false;
      return;
    }

    print('[TicketListBloc] Subscribing to private-tickets channel...');

    final channel = pusher.privateChannel(
      'private-tickets',
      authorizationDelegate: EndpointAuthorizableChannelTokenAuthorizationDelegate.forPrivateChannel(
        authorizationEndpoint: Uri.parse('https://cloud.almajd.info/api/broadcasting/auth'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ),
    );

    channel.bind('TicketMessageCreated').listen((event) {
      print('[TicketListBloc] TicketMessageCreated event received: ${event.data}');
      if (event.data == null) return;
      try {
        final Map<String, dynamic> payload = event.data is String ? jsonDecode(event.data) : event.data as Map<String, dynamic>;
        final data = payload['data'] is Map<String, dynamic> ? payload['data'] as Map<String, dynamic> : payload;
        final ticketId = data['ticket_id'] as int?;
        final body = data['body'] as String? ?? data['content'] as String? ?? '';
        
        print('[TicketListBloc] Parsed ticketId=$ticketId, body=$body');
        
        if (ticketId != null) {
          add(TicketListMessageReceived(ticketId: ticketId, messagePreview: body));
        }
      } catch (e) {
        print('[TicketListBloc] Error parsing event: $e');
      }
    });

    // Subscribe to channel — dart_pusher_channels handles pending
    // subscriptions and subscribes once the connection is established
    channel.subscribe();
    print('[TicketListBloc] Channel subscription requested');

    // Also listen for reconnection events — re-subscribe when connection comes back
    pusher.onConnectionEstablished.listen((_) {
      print('[TicketListBloc] Connection (re)established, ensuring channel subscription');
      channel.subscribe();
    });
  }

  Future<void> _onFetch(TicketListFetchRequested event, Emitter<TicketListState> emit) async {
    _setupWebsockets();
    if (!event.refresh) emit(TicketListLoading());
    try {
      final tickets = await ticketRepository.getTickets(
        type: event.typeFilter,
        todaySessions: event.todaySessions,
      );
      Map<String, dynamic>? stats;
      try { stats = await ticketRepository.getStats(); } catch (_) {}
      emit(TicketListLoaded(
        tickets: tickets,
        allTickets: tickets,
        activeFilter: event.typeFilter ?? 'all',
        stats: stats,
        todaySessions: event.todaySessions,
      ));
    } catch (e) {
      emit(const TicketListError('فشل تحميل التذاكر'));
    }
  }

  Future<void> _onRefresh(TicketListRefreshRequested event, Emitter<TicketListState> emit) async {
    final currentFilter = state is TicketListLoaded
        ? (state as TicketListLoaded).activeFilter
        : 'all';
    final currentToday = state is TicketListLoaded
        ? (state as TicketListLoaded).todaySessions
        : false;
    add(TicketListFetchRequested(
      typeFilter: currentFilter,
      refresh: true,
      todaySessions: currentToday,
    ));
  }

  Future<void> _onFilterChanged(TicketListFilterChanged event, Emitter<TicketListState> emit) async {
    add(TicketListFetchRequested(
      typeFilter: event.status,
      todaySessions: event.todaySessions,
    ));
  }

  Future<void> _onQuickAssign(TicketQuickAssign event, Emitter<TicketListState> emit) async {
    try {
      await ticketRepository.assignTicket(event.ticketId, event.userId);
      add(TicketListRefreshRequested());
    } catch (_) {}
  }

  Future<void> _onQuickStatusChange(TicketQuickStatusChange event, Emitter<TicketListState> emit) async {
    try {
      await ticketRepository.updateStatus(event.ticketId, event.status);
      add(TicketListRefreshRequested());
    } catch (_) {}
  }

  void _onSearch(TicketListSearchChanged event, Emitter<TicketListState> emit) {
    if (state is! TicketListLoaded) return;
    final s = state as TicketListLoaded;
    final q = event.query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? s.allTickets
        : s.allTickets.where((t) {
            return (t.guardianName?.toLowerCase().contains(q) ?? false) ||
                (t.guardianPhone?.contains(q) ?? false) ||
                (t.studentName?.toLowerCase().contains(q) ?? false) ||
                (t.lastMessage?.toLowerCase().contains(q) ?? false);
          }).toList();
    emit(TicketListLoaded(
      tickets: filtered,
      allTickets: s.allTickets,
      activeFilter: s.activeFilter,
      searchQuery: event.query,
      stats: s.stats,
    ));
  }

  Future<void> _onMessageReceived(TicketListMessageReceived event, Emitter<TicketListState> emit) async {
    if (state is! TicketListLoaded) return;
    final s = state as TicketListLoaded;
    
    // Check if the ticket already exists in our list
    final idx = s.allTickets.indexWhere((t) => t.id == event.ticketId);
    final updated = List<TicketModel>.from(s.allTickets);
    
    TicketModel bumped;
    
    if (idx == -1) {
      // 1. Unknown ticket — fetch it directly from backend so it appears instantly
      try {
        bumped = await ticketRepository.getTicket(event.ticketId);
      } catch (_) {
        return; // Silently fail if we can't fetch it
      }
    } else {
      // 2. Existing ticket — bump it to top
      final ticket = updated.removeAt(idx);
      bumped = TicketModel(
        id: ticket.id,
        ticketNumber: ticket.ticketNumber,
        status: ticket.status,
        priority: ticket.priority,
        guardianName: ticket.guardianName,
        guardianPhone: ticket.guardianPhone,
        studentName: ticket.studentName,
        lastMessage: event.messagePreview,
        unreadCount: ticket.unreadCount + 1,
        assignedToName: ticket.assignedToName,
        assignedToId: ticket.assignedToId,
        createdAt: ticket.createdAt,
        updatedAt: DateTime.now(), // Bump sort order
        slaDeadline: ticket.slaDeadline,
        tags: ticket.tags,
        messages: ticket.messages,
      );
    }
    
    updated.insert(0, bumped);

    // Apply current search filter
    final q = s.searchQuery.toLowerCase();
    final filtered = q.isEmpty
        ? updated
        : updated.where((t) {
            return (t.guardianName?.toLowerCase().contains(q) ?? false) ||
                (t.guardianPhone?.contains(q) ?? false) ||
                (t.studentName?.toLowerCase().contains(q) ?? false) ||
                (t.lastMessage?.toLowerCase().contains(q) ?? false);
          }).toList();

    emit(TicketListLoaded(
      tickets: filtered,
      allTickets: updated,
      activeFilter: s.activeFilter,
      searchQuery: s.searchQuery,
      stats: s.stats,
    ));
  }

  Future<void> _onDelete(TicketDeleteRequested event, Emitter<TicketListState> emit) async {
    if (state is! TicketListLoaded) return;
    
    // 1. Snapshot current state for rollback if needed
    final currentState = state as TicketListLoaded;
    
    // 2. Optimistically remove the ticket from UI
    final updatedAll = currentState.allTickets.where((t) => t.id != event.ticketId).toList();
    final updatedFiltered = currentState.tickets.where((t) => t.id != event.ticketId).toList();
    
    emit(TicketListLoaded(
      tickets: updatedFiltered,
      allTickets: updatedAll,
      activeFilter: currentState.activeFilter,
      searchQuery: currentState.searchQuery,
      stats: currentState.stats,
    ));

    // 3. Perform backend deletion
    try {
      await ticketRepository.deleteTicket(event.ticketId);
    } catch (_) {
      // 4. Rollback on failure
      emit(currentState);
    }
  }

  void _onReadStatusUpdated(TicketReadStatusUpdated event, Emitter<TicketListState> emit) {
    if (state is! TicketListLoaded) return;
    final s = state as TicketListLoaded;
    
    final updatedAll = s.allTickets.map((t) {
      if (t.id == event.ticketId && t.unreadCount > 0) {
        return TicketModel(
          id: t.id,
          ticketNumber: t.ticketNumber,
          status: t.status,
          priority: t.priority,
          guardianName: t.guardianName,
          guardianPhone: t.guardianPhone,
          studentName: t.studentName,
          lastMessage: t.lastMessage,
          unreadCount: 0,
          assignedToName: t.assignedToName,
          assignedToId: t.assignedToId,
          createdAt: t.createdAt,
          updatedAt: t.updatedAt,
          slaDeadline: t.slaDeadline,
          tags: t.tags,
          messages: t.messages,
        );
      }
      return t;
    }).toList();

    final updatedFiltered = s.tickets.map((t) {
      if (t.id == event.ticketId && t.unreadCount > 0) {
        return updatedAll.firstWhere((ut) => ut.id == event.ticketId);
      }
      return t;
    }).toList();

    emit(TicketListLoaded(
      tickets: updatedFiltered,
      allTickets: updatedAll,
      activeFilter: s.activeFilter,
      searchQuery: s.searchQuery,
      stats: s.stats,
    ));
  }
}
