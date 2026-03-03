import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/reminder_model.dart';
import '../bloc/reminder_list_bloc.dart';

class ReminderListScreen extends StatelessWidget {
  const ReminderListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ReminderListBloc>()..add(const ReminderListFetchRequested()),
      child: const _ReminderListView(),
    );
  }
}

class _ReminderListView extends StatelessWidget {
  const _ReminderListView();

  static const _filters = [
    {'key': 'all', 'label': 'الكل'},
    {'key': 'pending', 'label': 'معلّق'},
    {'key': 'sent', 'label': 'تم الإرسال'},
    {'key': 'failed', 'label': 'فشل'},
    {'key': 'cancelled', 'label': 'ملغى'},
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReminderListBloc, ReminderListState>(
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
                  final isActive = state is ReminderListLoaded && state.activeFilter == filter['key'];
                  return ChoiceChip(
                    label: Text(filter['label']!),
                    selected: isActive,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isActive ? Colors.white : AppColors.textSecondary,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                    ),
                    onSelected: (_) {
                      context.read<ReminderListBloc>().add(ReminderListFilterChanged(filter['key']!));
                    },
                  );
                },
              ),
            ),
            Expanded(child: _buildContent(context, state)),
          ],
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, ReminderListState state) {
    if (state is ReminderListLoading) return _buildShimmer();

    if (state is ReminderListError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.coral),
            const SizedBox(height: 16),
            Text(state.message, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<ReminderListBloc>().add(ReminderListRefreshRequested()),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (state is ReminderListLoaded) {
      if (state.reminders.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_off_outlined, size: 80, color: Colors.white.withValues(alpha: 0.2)),
              const SizedBox(height: 16),
              const Text('لا توجد تنبيهات', style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
            ],
          ),
        );
      }

      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          context.read<ReminderListBloc>().add(ReminderListRefreshRequested());
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          itemCount: state.reminders.length,
          itemBuilder: (context, index) => _ReminderCard(
            reminder: state.reminders[index],
            onCancel: state.reminders[index].status == 'pending'
                ? () => context.read<ReminderListBloc>().add(ReminderListCancelRequested(state.reminders[index].id))
                : null,
          ),
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
          height: 90,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ── Reminder Card ─────────────────────────────────────

class _ReminderCard extends StatelessWidget {
  final ReminderModel reminder;
  final VoidCallback? onCancel;

  const _ReminderCard({required this.reminder, this.onCancel});

  Color _statusColor(String status) {
    switch (status) {
      case 'pending': return AppColors.amber;
      case 'sent': return AppColors.success;
      case 'failed': return AppColors.coral;
      case 'cancelled': return AppColors.textSecondary;
      default: return AppColors.textSecondary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending': return Icons.schedule_send;
      case 'sent': return Icons.check_circle_outline;
      case 'failed': return Icons.error_outline;
      case 'cancelled': return Icons.cancel_outlined;
      default: return Icons.circle_outlined;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'session_reminder': return Icons.school_outlined;
      case 'guardian_notification': return Icons.family_restroom;
      case 'custom': return Icons.message_outlined;
      default: return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(reminder.status);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // type icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_typeIcon(reminder.type), size: 22, color: color),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          reminder.recipientName ?? reminder.recipientPhone,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_statusIcon(reminder.status), size: 12, color: color),
                            const SizedBox(width: 3),
                            Text(reminder.statusDisplay, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Message preview
                  if (reminder.messageBody != null)
                    Text(
                      reminder.messageBody!,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                  const SizedBox(height: 6),

                  // Footer: type + scheduled time
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.darkCardElevated, borderRadius: BorderRadius.circular(6)),
                        child: Text(reminder.typeDisplay, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.schedule, size: 12, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                      const SizedBox(width: 3),
                      Text(reminder.scheduledAtDisplay, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      const Spacer(),
                      if (onCancel != null)
                        GestureDetector(
                          onTap: onCancel,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.coral.withValues(alpha: 0.5)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('إلغاء', style: TextStyle(color: AppColors.coral, fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                        ),
                    ],
                  ),

                  // Failure reason
                  if (reminder.failureReason != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber, size: 13, color: AppColors.coral),
                          const SizedBox(width: 4),
                          Expanded(child: Text(reminder.failureReason!, style: const TextStyle(color: AppColors.coral, fontSize: 11))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
