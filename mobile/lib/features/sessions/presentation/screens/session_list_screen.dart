import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/session_model.dart';
import '../bloc/session_list_bloc.dart';

class SessionListScreen extends StatelessWidget {
  const SessionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SessionListBloc>()..add(const SessionListFetchRequested()),
      child: const _SessionListView(),
    );
  }
}

class _SessionListView extends StatelessWidget {
  const _SessionListView();

  static const _filters = [
    {'key': 'all', 'label': 'الكل'},
    {'key': 'scheduled', 'label': 'مجدولة'},
    {'key': 'completed', 'label': 'مكتملة'},
    {'key': 'cancelled', 'label': 'ملغاة'},
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionListBloc, SessionListState>(
      builder: (context, state) {
        return Column(
          children: [
            // ── Filter Chips ──
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
                  final isActive = state is SessionListLoaded && state.activeFilter == filter['key'];
                  return ChoiceChip(
                    label: Text(filter['label']!),
                    selected: isActive,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isActive ? Colors.white : AppColors.textSecondary,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                    ),
                    onSelected: (_) {
                      context.read<SessionListBloc>().add(SessionListFilterChanged(filter['key']!));
                    },
                  );
                },
              ),
            ),

            // ── Content ──
            Expanded(child: _buildContent(context, state)),
          ],
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, SessionListState state) {
    if (state is SessionListLoading) return _buildShimmer();

    if (state is SessionListError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.coral),
            const SizedBox(height: 16),
            Text(state.message, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<SessionListBloc>().add(SessionListRefreshRequested()),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (state is SessionListLoaded) {
      if (state.sessions.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_busy_outlined, size: 80, color: Colors.white.withValues(alpha: 0.2)),
              const SizedBox(height: 16),
              const Text('لا توجد حصص', style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
            ],
          ),
        );
      }

      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          context.read<SessionListBloc>().add(SessionListRefreshRequested());
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          itemCount: state.sessions.length,
          itemBuilder: (context, index) {
            return _SessionCard(
              session: state.sessions[index],
              onTap: () => context.push('/sessions/${state.sessions[index].id}'),
            );
          },
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.darkCard,
      highlightColor: AppColors.darkCardElevated,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: 5,
        itemBuilder: (_, __) => Container(
          height: 84,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// ── Session Card ──────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final SessionModel session;
  final VoidCallback onTap;

  const _SessionCard({required this.session, required this.onTap});

  Color _statusColor(String status) {
    switch (status) {
      case 'scheduled':
        return AppColors.amber;
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.coral;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'scheduled':
        return Icons.schedule;
      case 'completed':
        return Icons.check_circle_outline;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(session.status);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Status icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_statusIcon(session.status), size: 22, color: color),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            session.title,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            session.statusDisplay,
                            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (session.teacherName != null) ...[
                          Icon(Icons.person_outline, size: 13, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                          const SizedBox(width: 3),
                          Text(session.teacherName!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          const SizedBox(width: 12),
                        ],
                        Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                        const SizedBox(width: 3),
                        Text(session.dateDisplay, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        if (session.timeDisplay.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.access_time, size: 13, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                          const SizedBox(width: 3),
                          Text(session.timeDisplay, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ],
                    ),
                    if (session.cancellationReason != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 13, color: AppColors.coral),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                session.cancellationReason!,
                                style: const TextStyle(color: AppColors.coral, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_left, color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
