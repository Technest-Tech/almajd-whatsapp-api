import 'dart:async';
import 'dart:convert';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/api/websockets_client.dart';
import '../../../students/data/student_repository.dart';
import '../../../students/data/models/student_model.dart';
import '../../data/ticket_repository.dart';
import '../../data/models/ticket_model.dart';
import '../bloc/ticket_list_bloc.dart';
import '../widgets/ticket_card.dart';

// ─────────────────────────────────────────────────────────────
// Entry point — provides bloc
// ─────────────────────────────────────────────────────────────
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _InboxView();
  }
}

// ─────────────────────────────────────────────────────────────
// Main view — WhatsApp-style
// ─────────────────────────────────────────────────────────────
class _InboxView extends StatefulWidget {
  const _InboxView();

  @override
  State<_InboxView> createState() => _InboxViewState();
}

class _InboxViewState extends State<_InboxView> {
  final _searchController = TextEditingController();

  // Student search
  final _studentRepo = getIt<StudentRepository>();
  final _ticketRepo  = getIt<TicketRepository>();
  List<StudentModel> _studentResults = [];
  bool _searchingStudents = false;
  Timer? _debounce;
  Timer? _refreshTimer;
  int? _creatingStudentId; // which student is loading (creating ticket)

  // Status filter
  String _activeFilter = 'all';

  static const _filters = [
    {'key': 'all',       'label': 'الكل'},
    {'key': 'open',      'label': 'جديد'},
    {'key': 'assigned',  'label': 'معين'},
    {'key': 'pending',   'label': 'معلق'},
    {'key': 'escalated', 'label': 'متصاعد'},
    {'key': 'resolved',  'label': 'محلول'},
    {'key': 'closed',    'label': 'مغلق'},
  ];

  @override
  void initState() {
    super.initState();
    // Trigger fetch from the global BLoC if not already loaded
    final bloc = context.read<TicketListBloc>();
    if (bloc.state is TicketListInitial) {
      bloc.add(const TicketListFetchRequested());
    }
    // Silent refresh every 5 seconds so new messages always appear
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        context.read<TicketListBloc>().add(
          TicketListFetchRequested(statusFilter: _activeFilter, refresh: true),
        );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    _studentResults = [];
    _searchingStudents = false;
    context
        .read<TicketListBloc>()
        .add(const TicketListSearchChanged(''));
  }

  void _onSearchChanged(String query) {
    // Update ticket search immediately
    context.read<TicketListBloc>().add(TicketListSearchChanged(query));

    // Debounce student search
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _studentResults = [];
        _searchingStudents = false;
      });
      return;
    }

    setState(() => _searchingStudents = true);
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final students = await _studentRepo.getStudents(search: query, perPage: 10);
        if (mounted) setState(() {
          _studentResults = students;
          _searchingStudents = false;
        });
      } catch (_) {
        if (mounted) setState(() => _searchingStudents = false);
      }
    });
  }

  Future<void> _openStudentChat(StudentModel student) async {
    setState(() => _creatingStudentId = student.id);
    try {
      final ticketId = await _ticketRepo.createTicketForStudent(student.id);
      if (mounted) context.push('/tickets/$ticketId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل فتح المحادثة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _creatingStudentId = null);
    }
  }

  void _confirmDelete(TicketModel ticket) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2C34),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف المحادثة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
          'هل أنت متأكد من حذف هذه المحادثة؟ لا يمكن التراجع عن هذا الإجراء.',
          style: TextStyle(color: Color(0xFF8696A0), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Color(0xFF8696A0))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<TicketListBloc>().add(TicketDeleteRequested(ticket.id));
            },
            child: const Text('حذف', style: TextStyle(color: Color(0xFFEF5350), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TicketListBloc, TicketListState>(
      builder: (context, state) {
        // Extract stats for showing counts in chips
        final Map<String, dynamic>? stats =
            state is TicketListLoaded ? state.stats : null;

        return Stack(
          children: [
            Column(
              children: [
                // ── Search bar ──
                _SearchBar(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  onClose: _clearSearch,
                ),

                // ── Filter chips + stats (combined single row) ──
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final f = _filters[i];
                      final key = f['key']!;
                      final isActive = _activeFilter == key;

                      // Look up count for this filter from stats
                      int? count;
                      if (stats != null && key != 'all') {
                        count = stats[key] as int?;
                      }

                      return GestureDetector(
                        onTap: () {
                          setState(() => _activeFilter = key);
                          context.read<TicketListBloc>().add(
                                TicketListFilterChanged(key),
                              );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFF00A884)
                                : const Color(0xFF2A3942),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                f['label']!,
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.55),
                                  fontSize: 13,
                                  fontWeight: isActive
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                ),
                              ),
                              if (count != null && count > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? Colors.white.withValues(alpha: 0.25)
                                        : Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: TextStyle(
                                      color: isActive
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.55),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // ── Content ──
                Expanded(child: _buildContent(context, state)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, TicketListState state) {
    if (state is TicketListLoading) return _buildShimmer();

    if (state is TicketListError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.coral),
            const SizedBox(height: 16),
            Text(state.message,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context
                  .read<TicketListBloc>()
                  .add(TicketListRefreshRequested()),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (state is TicketListLoaded) {
      final hasSearchQuery = state.searchQuery.isNotEmpty;
      final hasStudentResults = _studentResults.isNotEmpty;
      final hasTicketResults = state.tickets.isNotEmpty;

      // No results at all
      if (!hasStudentResults && !hasTicketResults && !_searchingStudents) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline,
                  size: 80, color: Colors.white.withValues(alpha: 0.15)),
              const SizedBox(height: 16),
              Text(
                hasSearchQuery
                    ? 'لا توجد نتائج لـ "${state.searchQuery}"'
                    : 'لا توجد محادثات',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 16),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        color: const Color(0xFF00A884),
        backgroundColor: const Color(0xFF1F2C34),
        onRefresh: () async {
          context
              .read<TicketListBloc>()
              .add(TicketListRefreshRequested());
          await Future.delayed(const Duration(milliseconds: 400));
        },
        child: ListView(
          children: [
            // ── Student Results Section ──
            if (hasSearchQuery && (hasStudentResults || _searchingStudents)) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(
                  children: [
                    const Icon(Icons.person_search_rounded, size: 16, color: Color(0xFF00A884)),
                    const SizedBox(width: 6),
                    const Text('طلاب', style: TextStyle(color: Color(0xFF00A884), fontSize: 13, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (_searchingStudents)
                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00A884))),
                  ],
                ),
              ),
              ..._studentResults.map((student) => _StudentRow(
                student: student,
                isLoading: _creatingStudentId == student.id,
                onTap: () => _openStudentChat(student),
              )),
              if (hasTicketResults)
                const Divider(color: Colors.white12, indent: 16, endIndent: 16, height: 16),
            ],

            // ── Ticket Results Section ──
            if (hasSearchQuery && hasTicketResults && hasStudentResults)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: Row(
                  children: [
                    Icon(Icons.chat_rounded, size: 16, color: Color(0xFF8696A0)),
                    SizedBox(width: 6),
                    Text('محادثات', style: TextStyle(color: Color(0xFF8696A0), fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ...state.tickets.asMap().entries.map((entry) {
              final index = entry.key;
              final ticket = entry.value;
              return Column(
                children: [
                  TicketCard(
                    ticket: ticket,
                    onTap: () => context.push('/tickets/${ticket.id}'),
                    onLongPress: () => _confirmDelete(ticket),
                  ),
                  if (index < state.tickets.length - 1) const TicketDivider(),
                ],
              );
            }),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1F2C34),
      highlightColor: const Color(0xFF2A3942),
      child: ListView.separated(
        itemCount: 7,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Colors.transparent),
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const CircleAvatar(radius: 26, backgroundColor: Color(0xFF2A3942)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        height: 14,
                        width: 160,
                        decoration: BoxDecoration(
                            color: const Color(0xFF2A3942),
                            borderRadius: BorderRadius.circular(7))),
                    const SizedBox(height: 8),
                    Container(
                        height: 11,
                        width: 220,
                        decoration: BoxDecoration(
                            color: const Color(0xFF2A3942),
                            borderRadius: BorderRadius.circular(6))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Student search result row
// ─────────────────────────────────────────────────────────────
class _StudentRow extends StatelessWidget {
  final StudentModel student;
  final bool isLoading;
  final VoidCallback onTap;

  const _StudentRow({required this.student, required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final isAdmin = authState is AuthAuthenticated && authState.user.role == 'admin';

    final displayName = student.name.isNotEmpty && student.name != 'Unknown Contact'
        ? student.name
        : (isAdmin && student.phone != null ? '\u200E${student.phone}' : 'جهة اتصال غير معروفة');

    return InkWell(
      onTap: isLoading ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 22,
              backgroundColor: Color(0xFF2A3942),
              backgroundImage: AssetImage('assets/images/default_avatar.png'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  if (isAdmin && student.phone != null && student.phone!.isNotEmpty && displayName != '\u200E${student.phone}')
                    Text(
                      '\u200E${student.phone}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
                    ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00A884)))
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF00A884).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Color(0xFF00A884)),
                    SizedBox(width: 4),
                    Text('محادثة', style: TextStyle(color: Color(0xFF00A884), fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Inline search bar
// ─────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3942),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textDirection: TextDirection.rtl,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'بحث عن طالب أو رسالة...',
          hintStyle:
              TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 15),
          prefixIcon:
              Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.5)),
          suffixIcon: IconButton(
            icon: Icon(Icons.close_rounded,
                color: Colors.white.withValues(alpha: 0.5)),
            onPressed: onClose,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Stats summary strip
// ─────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _Chip('مفتوح', '${stats['open'] ?? 0}', AppColors.statusOpen),
          _Chip('معين', '${stats['assigned'] ?? 0}', AppColors.primary),
          _Chip('متصاعد', '${stats['escalated'] ?? 0}', AppColors.coral),
          _Chip('معلق', '${stats['pending'] ?? 0}', AppColors.amber),
        ],
      ),
    );
  }

  Widget _Chip(String label, String value, Color color) => Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: color.withValues(alpha: 0.8), fontSize: 11)),
          ],
        ),
      );
}
