import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/notification_repository.dart';
import '../../data/models/notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _repo = getIt<NotificationRepository>();
  List<NotificationItem> _items = [];
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final items = await _repo.getNotifications(perPage: 50);
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _repo.markAllAsRead();
      if (mounted) {
        setState(() {
          _items = _items.map((n) => NotificationItem(
            id: n.id, type: n.type, title: n.title,
            body: n.body, data: n.data,
            readAt: DateTime.now(), createdAt: n.createdAt,
          )).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _onTap(NotificationItem item) async {
    // Mark as read
    if (!item.isRead) {
      _repo.markAsRead(item.id).catchError((_) {});
      setState(() {
        final idx = _items.indexWhere((n) => n.id == item.id);
        if (idx >= 0) {
          _items[idx] = NotificationItem(
            id: item.id, type: item.type, title: item.title,
            body: item.body, data: item.data,
            readAt: DateTime.now(), createdAt: item.createdAt,
          );
        }
      });
    }

    // Navigate based on type
    if (item.type == 'message' && item.ticketId != null) {
      context.push('/tickets/${item.ticketId}');
    } else if (item.type == 'class_reminder' && item.sessionId != null) {
      context.push('/sessions/${item.sessionId}');
    }
  }

  // Build a flat display list with date headers and collapsed same-sender groups
  List<_DisplayEntry> _buildDisplayList() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Phase 1: group all items by day label
    final byDay = <String, List<NotificationItem>>{};
    for (final item in _items) {
      final d = DateTime(item.createdAt.year, item.createdAt.month, item.createdAt.day);
      String label;
      if (d == today) label = 'اليوم';
      else if (d == yesterday) label = 'أمس';
      else label = '${d.day}/${d.month}/${d.year}';
      byDay.putIfAbsent(label, () => []).add(item);
    }

    final result = <_DisplayEntry>[];

    for (final dayEntry in byDay.entries) {
      result.add(_DisplayEntry.header(dayEntry.key));

      // Phase 2: collapse consecutive same-sender messages into one grouped entry
      final items = dayEntry.value;
      int i = 0;
      while (i < items.length) {
        final cur = items[i];
        if (cur.type == 'message') {
          final guardianName = cur.guardianName ?? cur.title;
          // Collect all adjacent notifications from the same sender
          final group = <NotificationItem>[cur];
          int j = i + 1;
          while (j < items.length &&
              items[j].type == 'message' &&
              (items[j].guardianName ?? items[j].title) == guardianName) {
            group.add(items[j]);
            j++;
          }
          result.add(_DisplayEntry.messageGroup(group));
          i = j;
        } else {
          result.add(_DisplayEntry.single(cur));
          i++;
        }
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _items.where((n) => !n.isRead).length;

    return Column(
      children: [
        // Header with mark all read
        if (!_loading && _items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: unreadCount > 0
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    unreadCount > 0 ? '$unreadCount غير مقروءة' : 'لا توجد إشعارات جديدة',
                    style: TextStyle(
                      color: unreadCount > 0 ? AppColors.primary : Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                if (unreadCount > 0)
                  TextButton.icon(
                    onPressed: _markAllRead,
                    icon: const Icon(Icons.done_all, size: 16),
                    label: const Text('قراءة الكل', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),

        // Content
        Expanded(
          child: _loading
              ? _buildShimmer()
              : _items.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _load,
                      child: _buildList(),
                    ),
        ),
      ],
    );
  }

  Widget _buildList() {
    final displayList = _buildDisplayList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
      itemCount: displayList.length,
      itemBuilder: (context, index) {
        final entry = displayList[index];
        if (entry.isHeader) return _SectionHeader(label: entry.headerLabel!);
        if (entry.group != null && entry.group!.length > 1) {
          return _MessageGroupTile(
            group: entry.group!,
            onTap: () => _onTap(entry.group!.first),
          );
        }
        final item = entry.group?.first ?? entry.single!;
        return _NotificationTile(item: item, onTap: () => _onTap(item));
      },
    );
  }

  Widget _buildShimmer() => Shimmer.fromColors(
    baseColor: AppColors.darkCard,
    highlightColor: AppColors.darkCardElevated,
    child: ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      itemCount: 8,
      itemBuilder: (_, __) => Container(
        height: 72,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.notifications_off_outlined, size: 80, color: Colors.white.withValues(alpha: 0.12)),
        const SizedBox(height: 16),
        const Text('لا توجد إشعارات', style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
        const SizedBox(height: 8),
        Text(
          'ستظهر هنا الإشعارات عند وصول رسالة جديدة',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
// Display Entry (flat list item)
// ─────────────────────────────────────────────
class _DisplayEntry {
  final bool isHeader;
  final String? headerLabel;
  final List<NotificationItem>? group; // collapsed same-sender message group
  final NotificationItem? single;      // non-message or single-message notification

  const _DisplayEntry._({
    required this.isHeader,
    this.headerLabel,
    this.group,
    this.single,
  });

  factory _DisplayEntry.header(String label) =>
      _DisplayEntry._(isHeader: true, headerLabel: label);

  factory _DisplayEntry.messageGroup(List<NotificationItem> group) =>
      _DisplayEntry._(isHeader: false, group: group);

  factory _DisplayEntry.single(NotificationItem item) =>
      _DisplayEntry._(isHeader: false, single: item);
}

// ─────────────────────────────────────────────
// Message Group Tile (multiple messages from same sender)
// ─────────────────────────────────────────────
class _MessageGroupTile extends StatelessWidget {
  final List<NotificationItem> group;
  final VoidCallback onTap;
  const _MessageGroupTile({required this.group, required this.onTap});

  bool get _hasUnread => group.any((n) => !n.isRead);
  int get _unreadCount => group.where((n) => !n.isRead).length;
  NotificationItem get _latest => group.first;

  String get _timeLabel {
    final diff = DateTime.now().difference(_latest.createdAt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    return '${_latest.createdAt.hour.toString().padLeft(2, '0')}:${_latest.createdAt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final senderName = _latest.guardianName ?? _latest.title.replaceAll('رسالة جديدة من ', '');
    return InkWell(
      onTap: onTap,
      splashColor: AppColors.primary.withValues(alpha: 0.06),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _hasUnread ? AppColors.primary.withValues(alpha: 0.05) : Colors.transparent,
          border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon with sender count badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF53BDEB).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF53BDEB), size: 20),
                ),
                if (group.length > 1)
                  Positioned(
                    right: -6, bottom: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.darkCard, width: 1.5),
                      ),
                      child: Text(
                        '${group.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          senderName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: _hasUnread ? FontWeight.w700 : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _timeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: _hasUnread ? AppColors.primary : Colors.white.withValues(alpha: 0.3),
                          fontWeight: _hasUnread ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _unreadCount > 1
                        ? '$_unreadCount رسائل غير مقروءة'
                        : (_latest.body ?? ''),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: _hasUnread ? 0.6 : 0.35),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (_hasUnread)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 0.5,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Notification Tile
// ─────────────────────────────────────────────
class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;
  const _NotificationTile({required this.item, required this.onTap});

  IconData get _icon {
    switch (item.type) {
      case 'message':
        return Icons.chat_bubble_rounded;
      case 'class_reminder':
        return Icons.school_rounded;
      case 'reminder_log':
        return Icons.notifications_active_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color get _iconColor {
    switch (item.type) {
      case 'message':
        return const Color(0xFF53BDEB);
      case 'class_reminder':
        return const Color(0xFF00E676);
      case 'reminder_log':
        return const Color(0xFFFFA726);
      default:
        return AppColors.primary;
    }
  }

  String get _timeLabel {
    final now = DateTime.now();
    final diff = now.difference(item.createdAt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    return '${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: AppColors.primary.withValues(alpha: 0.06),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: item.isRead
              ? Colors.transparent
              : AppColors.primary.withValues(alpha: 0.04),
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, color: _iconColor, size: 20),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: item.isRead ? FontWeight.w400 : FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _timeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: item.isRead
                              ? Colors.white.withValues(alpha: 0.3)
                              : AppColors.primary,
                          fontWeight: item.isRead ? FontWeight.normal : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (item.body != null && item.body!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.body!,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: item.isRead ? 0.35 : 0.6),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Unread dot
            if (!item.isRead)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 0, left: 4),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
