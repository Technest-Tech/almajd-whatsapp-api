import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/api/api_client.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../../features/tickets/presentation/bloc/ticket_list_bloc.dart';
import '../../../../features/tickets/data/ticket_repository.dart';
import '../../../../features/notifications/data/notification_repository.dart';
import '../../../../features/sessions/data/session_repository.dart';

/// Sent by the shell AppBar when the search icon is tapped.
/// The InboxScreen listens for this and toggles its search bar.
class InboxSearchNotification extends Notification {}

class DashboardShell extends StatefulWidget {
  final Widget child;
  const DashboardShell({super.key, required this.child});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _currentIndex = 0;
  int _unreadCount = 0;
  int _notifUnreadCount = 0;
  int _pendingSessionsCount = 0;
  Timer? _badgeTimer;
  Timer? _debounce;
  late final StreamSubscription _blocSub;

  @override
  void initState() {
    super.initState();

    // Determine role early to avoid unnecessary API calls
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    final isCalendarManager = user?.primaryRole == 'calendar_manager';

    if (!isCalendarManager) {
      // Trigger initial ticket load + websocket connection from the global BLoC
      final bloc = context.read<TicketListBloc>();
      if (bloc.state is TicketListInitial) {
        bloc.add(const TicketListFetchRequested());
      }
      // Lightweight unread count poll every 30s
      _fetchUnreadCount();
      _badgeTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _fetchUnreadCount();
      });
      // Debounced refresh on WebSocket updates (wait 3s after last event)
      _blocSub = bloc.stream.listen((state) {
        if (state is TicketListLoaded && mounted) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(seconds: 3), () {
            if (mounted) _fetchUnreadCount();
          });
        }
      });
    } else {
      // Calendar manager: no ticket/session API calls, set up a no-op stream sub
      final bloc = context.read<TicketListBloc>();
      _blocSub = bloc.stream.listen((_) {});
    }
  }

  Future<void> _fetchUnreadCount() async {
    // Skip for calendar_manager — these endpoints require tickets/sessions permissions
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    if (user?.primaryRole == 'calendar_manager') return;

    try {
      final ticketRepo = getIt<TicketRepository>();
      final notifRepo = getIt<NotificationRepository>();
      final sessionRepo = getIt<SessionRepository>();
      final results = await Future.wait([
        ticketRepo.getUnreadCount(),
        notifRepo.getUnreadCount(),
        sessionRepo.getPendingCount(),
      ]);
      if (mounted) {
        setState(() {
          _unreadCount = results[0];
          _notifUnreadCount = results[1];
          _pendingSessionsCount = results[2];
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _badgeTimer?.cancel();
    _debounce?.cancel();
    _blocSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated || state is AuthError) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/login');
          });
        }
        // Safety redirect: calendar_manager should never be in the shell
        if (state is AuthAuthenticated && state.user.primaryRole == 'calendar_manager') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/calendar');
          });
        }
      },
      builder: (context, state) {
        final user = state is AuthAuthenticated ? state.user : null;

        // Calendar manager: render a blank scaffold while redirecting
        if (user?.primaryRole == 'calendar_manager') {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return BlocBuilder<TicketListBloc, TicketListState>(
          builder: (context, ticketState) {
            // Use the lightweight polled unread count, or fall back to BLoC state
            int unreadCount = _unreadCount;
            if (unreadCount == 0 && ticketState is TicketListLoaded) {
              unreadCount = ticketState.allTickets.fold(0, (sum, t) => sum + t.unreadCount);
            }
            final navItems = _getNavItems(user, unreadCount, _pendingSessionsCount);

            return Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            title: Text(navItems[_currentIndex]['label'] as String),
            actions: [
              // Search button (only on inbox tab)
              if (navItems[_currentIndex]['path'] == '/inbox' || navItems[_currentIndex]['path'] == '/tickets')
                IconButton(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () {
                    InboxSearchNotification().dispatch(context);
                  },
                ),
              // Notification bell — hidden for regular supervisors
              if (user?.primaryRole != 'supervisor')
                IconButton(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications_outlined),
                      if (_notifUnreadCount > 0)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            decoration: const BoxDecoration(
                              color: AppColors.coral,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              _notifUnreadCount > 9 ? '9+' : '$_notifUnreadCount',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  onPressed: () => context.go('/notifications'),
                ),
              // Avatar
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: GestureDetector(
                  onTap: () => _showProfileSheet(context, user),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      user?.initials ?? '؟',
                      style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Container(
            color: AppColors.darkBg,
            child: widget.child,
          ),
          floatingActionButton: _buildCenterFAB(
            navItems,
            role: (user?.primaryRole ?? 'supervisor'),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: _buildBottomBar(context, navItems),
        );
      },
    );
  },
);
  }

  Future<void> _onNavTap(int index, String path) async {
    // Close any open bottom sheets/dialogs before changing the shell route
    await Navigator.of(context).maybePop();
    if (!mounted) return;
    setState(() => _currentIndex = index);
    context.go(path);
  }

  Widget _buildCenterFAB(
    List<Map<String, dynamic>> navItems, {
    required String role,
  }) {
    final centerIndex = navItems.indexWhere((e) => e['path'] == '/classes');
    final safeCenterIndex = centerIndex == -1 ? (navItems.length ~/ 2) : centerIndex;
    final isSelected = _currentIndex == safeCenterIndex;
    // Keep center FAB styling consistent across roles (same as admin).
    final fabBackgroundColor = AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isSelected ? 0.5 : 0.3),
            blurRadius: isSelected ? 16 : 10,
            spreadRadius: isSelected ? 2 : 0,
          ),
        ],
      ),
      child: FloatingActionButton(
        elevation: 0,
        backgroundColor: fabBackgroundColor,
        onPressed: () {
          _onNavTap(safeCenterIndex, '/classes');
        },
        // Keep it simple + visible: icon-only button (no tiny label).
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              isSelected ? Icons.notifications_active_rounded : Icons.notifications_outlined,
              color: Colors.white,
              size: 28,
            ),
            if ((navItems[safeCenterIndex]['badge'] as int? ?? 0) > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: const BoxDecoration(
                    color: AppColors.coral,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 14),
                  child: Text(
                    '${navItems[safeCenterIndex]['badge']}',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, List<Map<String, dynamic>> navItems) {
    final centerIndex = navItems.indexWhere((e) => e['path'] == '/classes');
    final safeCenterIndex = centerIndex == -1 ? (navItems.length ~/ 2) : centerIndex;
    final leftItems = navItems.sublist(0, safeCenterIndex);
    final rightItems = navItems.sublist(safeCenterIndex + 1);

    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: AppColors.darkCard,
      elevation: 8,
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            // Left side items
                ...leftItems.asMap().entries.map((e) => _buildNavItem(
                      context,
                      icon: e.value['icon'] as IconData,
                      selectedIcon: e.value['selectedIcon'] as IconData,
                      label: e.value['label'] as String,
                      isSelected: _currentIndex == e.key,
                      badge: (e.value['badge'] as int?) ?? 0,
                      onTap: () => _onNavTap(e.key, e.value['path'] as String),
                    )),
            // Center spacer for FAB
            const Expanded(child: SizedBox()),
            // Right side items
            ...rightItems.asMap().entries.map((e) {
              final actualIndex = safeCenterIndex + 1 + e.key;
              return _buildNavItem(
                context,
                icon: e.value['icon'] as IconData,
                selectedIcon: e.value['selectedIcon'] as IconData,
                label: e.value['label'] as String,
                isSelected: _currentIndex == actualIndex,
                badge: (e.value['badge'] as int?) ?? 0,
                onTap: () => _onNavTap(actualIndex, e.value['path'] as String),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Supervisor fixed layout: 5 controls in a single row:
  /// Inbox, Teachers, Students, Reminders(classes) as a normal button, Settings.
  ///
  /// This avoids notch/FAB alignment issues and guarantees spacing/order.
  Widget _buildSupervisorBottomBar(BuildContext context) {
    const barHeight = 64.0;
    return Material(
      color: AppColors.darkCard,
      elevation: 8,
      child: SizedBox(
        height: barHeight,
        child: Row(
          children: [
            _buildNavItem(
              context,
              icon: Icons.inbox_outlined,
              selectedIcon: Icons.inbox_rounded,
              label: 'الوارد',
              isSelected: _currentIndex == 0,
              badge: _unreadCount,
              onTap: () => _onNavTap(0, '/inbox'),
            ),
            _buildNavItem(
              context,
              icon: Icons.school_outlined,
              selectedIcon: Icons.school_rounded,
              label: 'المعلمون',
              isSelected: _currentIndex == 1,
              onTap: () => _onNavTap(1, '/teachers'),
            ),
            _buildNavItem(
              context,
              icon: Icons.people_outline,
              selectedIcon: Icons.people_rounded,
              label: 'الطلاب',
              isSelected: _currentIndex == 2,
              onTap: () => _onNavTap(2, '/students'),
            ),
            _buildSupervisorReminderItem(
              context,
              isSelected: _currentIndex == 3,
              badge: 0,
              onTap: () => _onNavTap(3, '/classes'),
            ),
            _buildNavItem(
              context,
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings_rounded,
              label: 'الإعدادات',
              isSelected: _currentIndex == 4,
              onTap: () => _onNavTap(4, '/settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupervisorReminderItem(
    BuildContext context, {
    required bool isSelected,
    required int badge,
    required VoidCallback onTap,
  }) {
    // "Normal" button inside the bar, but with coral color + better visibility.
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? Icons.notifications_active_rounded : Icons.notifications_outlined,
                  color: AppColors.coral,
                  size: 26,
                ),
                if (badge > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.coral,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 14),
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'التذكيرات',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.coral,
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  size: 22,
                ),
                if (badge > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.coral,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 14),
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getNavItems(UserModel? user, int unreadCount, int pendingCount) {
    final role = user?.primaryRole ?? 'supervisor';

    // Calendar manager never lands in the shell, but guard gracefully just in case
    if (role == 'calendar_manager') return [];

    final items = <Map<String, dynamic>>[
      {
        'icon': Icons.inbox_outlined,
        'selectedIcon': Icons.inbox_rounded,
        'label': 'الوارد',
        'path': '/inbox',
        'badge': unreadCount,
      },
    ];

    // ── LEFT items (before center) ──
    if (role == 'admin') {
      items.add({
        'icon': Icons.people_outline,
        'selectedIcon': Icons.people_rounded,
        'label': 'الطلاب',
        'path': '/students',
      });
    } else if (role == 'senior_supervisor') {
      items.add({
        'icon': Icons.group_outlined,
        'selectedIcon': Icons.group_rounded,
        'label': 'المشرفون',
        'path': '/supervisors',
      });
    } else {
      // Regular Supervisor
      items.add({
        'icon': Icons.people_outline,
        'selectedIcon': Icons.people_rounded,
        'label': 'الطلاب',
        'path': '/students',
      });
    }

    // ── CENTER: التذكيرات ──
    items.add({
      'icon': Icons.notifications_outlined,
      'selectedIcon': Icons.notifications_active_rounded,
      'label': 'التذكيرات',
      'path': '/classes',
      'badge': pendingCount,
    });

    // ── RIGHT items (after center) ──
    if (role == 'admin') {
      items.addAll([
        {
          'icon': Icons.school_outlined,
          'selectedIcon': Icons.school_rounded,
          'label': 'المعلمون',
          'path': '/teachers',
        },
        {
          'icon': Icons.dashboard_outlined,
          'selectedIcon': Icons.dashboard_rounded,
          'label': 'الإدارة',
          'path': '/management',
        },
      ]);
    } else if (role == 'senior_supervisor') {
      items.addAll([
        {
          'icon': Icons.bar_chart_outlined,
          'selectedIcon': Icons.bar_chart_rounded,
          'label': 'التقارير',
          'path': '/analytics',
        },
        {
          'icon': Icons.settings_outlined,
          'selectedIcon': Icons.settings_rounded,
          'label': 'الإعدادات',
          'path': '/settings',
        },
      ]);
    } else {
      // Regular Supervisor
      items.addAll([
        {
          'icon': Icons.school_outlined,
          'selectedIcon': Icons.school_rounded,
          'label': 'المعلمون',
          'path': '/teachers',
        },
        {
          'icon': Icons.settings_outlined,
          'selectedIcon': Icons.settings_rounded,
          'label': 'الإعدادات',
          'path': '/settings',
        },
      ]);
    }

    return items;
  }

  void _showProfileSheet(BuildContext context, UserModel? user) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primary,
              child: Text(
                user?.initials ?? '؟',
                style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            Text(user?.name ?? '', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(user?.roleDisplayName ?? '', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(user?.email ?? '', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 24),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.read<AuthBloc>().add(AuthLogoutRequested());
                  context.go('/login');
                },
                icon: const Icon(Icons.logout, color: AppColors.coral),
                label: const Text('تسجيل الخروج', style: TextStyle(color: AppColors.coral)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
