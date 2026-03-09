import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/api/api_client.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../../features/tickets/presentation/bloc/ticket_list_bloc.dart';
import '../../../../features/tickets/data/ticket_repository.dart';

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
  Timer? _badgeTimer;

  @override
  void initState() {
    super.initState();
    // Trigger initial ticket load + websocket connection from the global BLoC
    final bloc = context.read<TicketListBloc>();
    if (bloc.state is TicketListInitial) {
      bloc.add(const TicketListFetchRequested());
    }
    // Lightweight unread count poll every 10s (just returns a number, no ticket data)
    _fetchUnreadCount();
    _badgeTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchUnreadCount();
    });
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final repo = getIt<TicketRepository>();
      final count = await repo.getUnreadCount();
      if (mounted && count != _unreadCount) {
        setState(() => _unreadCount = count);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _badgeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state is AuthAuthenticated ? state.user : null;

        return BlocBuilder<TicketListBloc, TicketListState>(
          builder: (context, ticketState) {
            // Use the lightweight polled unread count, or fall back to BLoC state
            int unreadCount = _unreadCount;
            if (unreadCount == 0 && ticketState is TicketListLoaded) {
              unreadCount = ticketState.allTickets.fold(0, (sum, t) => sum + t.unreadCount);
            }
            final navItems = _getNavItems(user, unreadCount);

            return Scaffold(
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
              // Notification bell
              IconButton(
                icon: Stack(
                  children: [
                    const Icon(Icons.notifications_outlined),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.coral,
                          shape: BoxShape.circle,
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
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
            child: Container(
              key: ValueKey(GoRouterState.of(context).uri.toString()),
              color: AppColors.darkBg,
              child: widget.child,
            ),
          ),
          floatingActionButton: _buildCenterFAB(context, navItems),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: _buildBottomBar(context, navItems),
        );
      },
      );
      },
    );
  }

  Widget _buildCenterFAB(BuildContext context, List<Map<String, dynamic>> navItems) {
    final centerIndex = navItems.length ~/ 2;
    final isSelected = _currentIndex == centerIndex;
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
        backgroundColor: AppColors.primary,
        onPressed: () {
          setState(() => _currentIndex = centerIndex);
          context.go('/classes');
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? Icons.notifications_active_rounded : Icons.notifications_outlined,
              color: Colors.white,
              size: 24,
            ),
            const Text(
              'التذكيرات',
              style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, List<Map<String, dynamic>> navItems) {
    final centerIndex = navItems.length ~/ 2;
    final leftItems = navItems.sublist(0, centerIndex);
    final rightItems = navItems.sublist(centerIndex + 1);

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
                  onTap: () {
                    setState(() => _currentIndex = e.key);
                    context.go(e.value['path'] as String);
                  },
                )),
            // Center spacer for FAB
            const Expanded(child: SizedBox()),
            // Right side items
            ...rightItems.asMap().entries.map((e) {
              final actualIndex = centerIndex + 1 + e.key;
              return _buildNavItem(
                context,
                icon: e.value['icon'] as IconData,
                selectedIcon: e.value['selectedIcon'] as IconData,
                label: e.value['label'] as String,
                isSelected: _currentIndex == actualIndex,
                badge: (e.value['badge'] as int?) ?? 0,
                onTap: () {
                  setState(() => _currentIndex = actualIndex);
                  context.go(e.value['path'] as String);
                },
              );
            }),
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

  List<Map<String, dynamic>> _getNavItems(UserModel? user, int unreadCount) {
    final role = user?.primaryRole ?? 'supervisor';

    // Left side items
    final items = <Map<String, dynamic>>[
      {
        'icon': Icons.inbox_outlined,
        'selectedIcon': Icons.inbox_rounded,
        'label': 'الوارد',
        'path': '/inbox',
        'badge': unreadCount,
      },
    ];

    // ── Role-specific LEFT items (before center) ──
    if (role == 'admin') {
      items.add({
        'icon': Icons.people_outline,
        'selectedIcon': Icons.people_rounded,
        'label': 'الطلاب',
        'path': '/students',
      });
    }

    // ── CENTER: التذكيرات (placeholder in list for index math) ──
    items.add({
      'icon': Icons.notifications_outlined,
      'selectedIcon': Icons.notifications_active_rounded,
      'label': 'الإشعارات',
      'path': '/notifications',
    });

    // ── Role-specific RIGHT items (after center) ──
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
      // Add left items before center
      items.insertAll(items.length - 1, [
        {
          'icon': Icons.group_outlined,
          'selectedIcon': Icons.group_rounded,
          'label': 'الفريق',
          'path': '/users',
        },
      ]);
      // Add right items after center
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
      // Supervisor
      items.insertAll(items.length - 1, [
        {
          'icon': Icons.search_outlined,
          'selectedIcon': Icons.search_rounded,
          'label': 'البحث',
          'path': '/tickets',
        },
      ]);
      items.add({
        'icon': Icons.settings_outlined,
        'selectedIcon': Icons.settings_rounded,
        'label': 'الإعدادات',
        'path': '/settings',
      });
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

            // Availability toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('الحالة: '),
                ChoiceChip(
                  label: const Text('متاح'),
                  selected: user?.availability == 'available',
                  selectedColor: AppColors.success,
                  onSelected: (_) {
                    context.read<AuthBloc>().add(const AuthAvailabilityChanged('available'));
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('مشغول'),
                  selected: user?.availability == 'busy',
                  selectedColor: AppColors.amber,
                  onSelected: (_) {
                    context.read<AuthBloc>().add(const AuthAvailabilityChanged('busy'));
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
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
