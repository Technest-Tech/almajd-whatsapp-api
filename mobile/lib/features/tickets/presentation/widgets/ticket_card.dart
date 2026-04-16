import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:ui' show FontFeature;

import '../../../../core/theme/app_theme.dart';
import '../../data/models/ticket_model.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

// ─────────────────────────────────────────────────────────────
// Compact WhatsApp-style chat row
// ─────────────────────────────────────────────────────────────
class TicketCard extends StatelessWidget {
  final TicketModel ticket;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TicketCard({super.key, required this.ticket, this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final isAdmin = authState is AuthAuthenticated && authState.user.roles.contains('admin');

    final hasGuardianName = ticket.guardianName?.isNotEmpty == true && ticket.guardianName != 'Unknown Contact';
    final hasStudentName  = ticket.studentName?.isNotEmpty == true;

    final displayName = hasGuardianName
        ? ticket.guardianName!
        : hasStudentName
            ? ticket.studentName!
            : (isAdmin && ticket.guardianPhone != null ? '\u200E${ticket.guardianPhone}' : 'جهة اتصال غير معروفة');

    final sub = (hasGuardianName && hasStudentName) ? ticket.studentName! : null;
    final preview = _buildPreview();
    final timeLabel = _timeLabel();
    final isUnread = ticket.unreadCount > 0;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      splashColor: AppColors.primary.withValues(alpha: 0.06),
      highlightColor: AppColors.primary.withValues(alpha: 0.03),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // ── Avatar ──
            _Avatar(isUnread: isUnread),
            const SizedBox(width: 12),

            // ── Content ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Row 1: name + time
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            if (sub != null) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                flex: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    sub,
                                    style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.5)),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: isUnread ? AppColors.primary : Colors.white.withValues(alpha: 0.35),
                          fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 3),

                  // Row 2: preview + status/unread
                  Row(
                    children: [
                      // Status indicator dot
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _statusDotColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: isUnread
                                ? Colors.white.withValues(alpha: 0.75)
                                : Colors.white.withValues(alpha: 0.38),
                            fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          constraints: const BoxConstraints(minWidth: 18),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            ticket.unreadCount > 99 ? '99+' : '${ticket.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color get _statusDotColor {
    switch (ticket.status) {
      case 'open':       return const Color(0xFF53BDEB);
      case 'assigned':   return AppColors.primary;
      case 'pending':    return const Color(0xFFFFB74D);
      case 'escalated':  return const Color(0xFFEF5350);
      case 'resolved':   return const Color(0xFF25D366);
      case 'closed':     return const Color(0xFF8696A0);
      default:           return const Color(0xFF8696A0);
    }
  }

  String _buildPreview() {
    if (ticket.lastMessage != null && ticket.lastMessage!.isNotEmpty) {
      return ticket.lastMessage!;
    }
    switch (ticket.status) {
      case 'open':    return 'تذكرة جديدة';
      case 'closed':  return 'تم إغلاق المحادثة';
      default:        return 'لا توجد رسائل';
    }
  }

  String _timeLabel() {
    final now = DateTime.now();
    final t = ticket.updatedAt;
    final diff = now.difference(t);

    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inDays == 0) {
      final isPm = t.hour >= 12;
      final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
      final m = t.minute.toString().padLeft(2, '0');
      return '$h12:$m ${isPm ? 'م' : 'ص'}';
    }
    if (diff.inDays == 1) return 'أمس';
    if (diff.inDays < 7) return _weekdayAr(t.weekday);
    return '${t.day}/${t.month}';
  }

  String _weekdayAr(int d) {
    const days = ['', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    return days[d];
  }
}

// ─────────────────────────────────────────────────────────────
// Compact avatar with online-style ring for unread
// ─────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final bool isUnread;

  const _Avatar({required this.isUnread});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: isUnread
            ? Border.all(color: AppColors.primary, width: 2)
            : Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      child: const CircleAvatar(
        radius: 22,
        backgroundColor: Color(0xFF2A3942), // WhatsApp dark grey fallback
        backgroundImage: AssetImage('assets/images/default_avatar.png'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Thin divider between cards
// ─────────────────────────────────────────────────────────────
class TicketDivider extends StatelessWidget {
  const TicketDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.4,
      indent: 74,
      color: Colors.white.withValues(alpha: 0.06),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Status Badge
// ─────────────────────────────────────────────────────────────
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
      case 'open':       return AppColors.statusOpen;
      case 'assigned':   return AppColors.primary;
      case 'pending':    return AppColors.statusPending;
      case 'resolved':   return AppColors.statusResolved;
      case 'closed':     return AppColors.statusClosed;
      case 'escalated':  return AppColors.statusEscalated;
      default:           return AppColors.textSecondary;
    }
  }
}
