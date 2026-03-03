import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';

import '../bloc/ticket_list_bloc.dart';
import '../widgets/ticket_card.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<TicketListBloc>()..add(const TicketListFetchRequested()),
      child: const _InboxView(),
    );
  }
}

class _InboxView extends StatelessWidget {
  const _InboxView();

  static const _filters = [
    {'key': 'all', 'label': 'الكل'},
    {'key': 'open', 'label': 'جديد'},
    {'key': 'assigned', 'label': 'معين'},
    {'key': 'pending', 'label': 'معلق'},
    {'key': 'escalated', 'label': 'متصاعد'},
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TicketListBloc, TicketListState>(
      builder: (context, state) {
        return Column(
          children: [
            // ── Stats Row ──
            if (state is TicketListLoaded && state.stats != null)
              _buildStatsRow(context, state.stats!),

            // ── Filter Tabs ──
            Container(
              height: 44,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isActive = state is TicketListLoaded &&
                      state.activeFilter == filter['key'];
                  return ChoiceChip(
                    label: Text(filter['label']!),
                    selected: isActive,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isActive ? Colors.white : AppColors.textSecondary,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                    ),
                    onSelected: (_) {
                      context.read<TicketListBloc>().add(
                        TicketListFilterChanged(filter['key']!),
                      );
                    },
                  );
                },
              ),
            ),

            // ── Content ──
            Expanded(
              child: _buildContent(context, state),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatsRow(BuildContext context, Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _StatChip(
            label: 'مفتوح',
            value: '${stats['open'] ?? 0}',
            color: AppColors.statusOpen,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'معين',
            value: '${stats['assigned'] ?? 0}',
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'متصاعد',
            value: '${stats['escalated'] ?? 0}',
            color: AppColors.coral,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'معلق',
            value: '${stats['pending'] ?? 0}',
            color: AppColors.amber,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, TicketListState state) {
    if (state is TicketListLoading) {
      return _buildShimmer();
    }

    if (state is TicketListError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.coral),
            const SizedBox(height: 16),
            Text(state.message, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<TicketListBloc>().add(TicketListRefreshRequested()),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (state is TicketListLoaded) {
      if (state.tickets.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 80, color: Colors.white.withValues(alpha: 0.2)),
              const SizedBox(height: 16),
              const Text('لا توجد تذاكر', style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
              const SizedBox(height: 8),
              const Text('ستظهر التذاكر الجديدة هنا', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        );
      }

      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          context.read<TicketListBloc>().add(TicketListRefreshRequested());
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          itemCount: state.tickets.length,
          itemBuilder: (context, index) {
            final ticket = state.tickets[index];
            return Dismissible(
              key: ValueKey(ticket.id),
              background: _swipeBackground(
                alignment: Alignment.centerRight,
                color: AppColors.primary,
                icon: Icons.person_add,
                label: 'تعيين',
              ),
              secondaryBackground: _swipeBackground(
                alignment: Alignment.centerLeft,
                color: AppColors.amber,
                icon: Icons.pause_circle_outline,
                label: 'معلق',
              ),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  // Quick assign to self — needs current user id
                  // For now just show feedback
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم التعيين'), backgroundColor: AppColors.primary),
                  );
                } else {
                  context.read<TicketListBloc>().add(
                    TicketQuickStatusChange(ticketId: ticket.id, status: 'pending'),
                  );
                }
                return false; // Don't actually dismiss
              },
              child: TicketCard(
                ticket: ticket,
                onTap: () => context.push('/tickets/${ticket.id}'),
              ),
            );
          },
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _swipeBackground({
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      alignment: alignment,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.darkCard,
      highlightColor: AppColors.darkCardElevated,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: 5,
        itemBuilder: (_, __) => Container(
          height: 100,
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              label,
              style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
