import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/ticket_model.dart';

class TicketCard extends StatelessWidget {
  final TicketModel ticket;
  final VoidCallback? onTap;

  const TicketCard({super.key, required this.ticket, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // ── Priority Strip ──
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: _priorityColor,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
              ),

              // ── Content ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: ticket number + SLA pill
                      Row(
                        children: [
                          Text(
                            ticket.ticketNumber,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(status: ticket.status, label: ticket.statusDisplay),
                          const Spacer(),
                          if (ticket.slaDeadline != null)
                            SlaTimerPill(deadline: ticket.slaDeadline!),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Row 2: Guardian name
                      Text(
                        ticket.guardianName ?? 'ولي أمر غير معروف',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),

                      // Student name
                      if (ticket.studentName != null)
                        Text(
                          'الطالب: ${ticket.studentName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      const SizedBox(height: 4),

                      // Last message preview
                      if (ticket.lastMessage != null)
                        Text(
                          ticket.lastMessage!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      const SizedBox(height: 6),

                      // Row 3: time ago + unread badge + tags
                      Row(
                        children: [
                          Text(
                            ticket.timeAgo,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                          if (ticket.unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${ticket.unreadCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          // Priority chip
                          PriorityChip(priority: ticket.priority, label: ticket.priorityDisplay),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color get _priorityColor {
    switch (ticket.priority) {
      case 'urgent': return AppColors.priorityUrgent;
      case 'high': return AppColors.priorityHigh;
      case 'normal': return AppColors.priorityNormal;
      case 'low': return AppColors.priorityLow;
      default: return AppColors.priorityNormal;
    }
  }
}

// ── Status Badge ──

class StatusBadge extends StatelessWidget {
  final String status;
  final String label;

  const StatusBadge({super.key, required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _statusColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _statusColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color get _statusColor {
    switch (status) {
      case 'open': return AppColors.statusOpen;
      case 'assigned': return AppColors.primary;
      case 'pending': return AppColors.statusPending;
      case 'resolved': return AppColors.statusResolved;
      case 'closed': return AppColors.statusClosed;
      case 'escalated': return AppColors.statusEscalated;
      default: return AppColors.textSecondary;
    }
  }
}

// ── Priority Chip ──

class PriorityChip extends StatelessWidget {
  final String priority;
  final String label;

  const PriorityChip({super.key, required this.priority, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_icon, size: 12, color: _color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  IconData get _icon {
    switch (priority) {
      case 'urgent': return Icons.error;
      case 'high': return Icons.arrow_upward;
      case 'normal': return Icons.remove;
      case 'low': return Icons.arrow_downward;
      default: return Icons.remove;
    }
  }

  Color get _color {
    switch (priority) {
      case 'urgent': return AppColors.priorityUrgent;
      case 'high': return AppColors.priorityHigh;
      case 'normal': return AppColors.priorityNormal;
      case 'low': return AppColors.priorityLow;
      default: return AppColors.priorityNormal;
    }
  }
}

// ── SLA Timer Pill ──

class SlaTimerPill extends StatefulWidget {
  final DateTime deadline;

  const SlaTimerPill({super.key, required this.deadline});

  @override
  State<SlaTimerPill> createState() => _SlaTimerPillState();
}

class _SlaTimerPillState extends State<SlaTimerPill> {
  late Timer _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateRemaining() {
    final diff = widget.deadline.difference(DateTime.now());
    setState(() {
      _remaining = diff.isNegative ? Duration.zero : diff;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hours = _remaining.inHours.toString().padLeft(2, '0');
    final minutes = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    final isBreached = _remaining == Duration.zero;

    Color color;
    if (isBreached) {
      color = AppColors.slaRed;
    } else if (_remaining.inMinutes < 30) {
      color = AppColors.slaRed;
    } else if (_remaining.inHours < 2) {
      color = AppColors.slaYellow;
    } else {
      color = AppColors.slaGreen;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isBreached ? Icons.warning_amber_rounded : Icons.timer_outlined,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            isBreached ? 'منتهي' : '$hours:$minutes:$seconds',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
