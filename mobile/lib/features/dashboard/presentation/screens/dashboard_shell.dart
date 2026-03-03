import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/data/models/user_model.dart';

class DashboardShell extends StatefulWidget {
  final Widget child;
  const DashboardShell({super.key, required this.child});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state is AuthAuthenticated ? state.user : null;
        final navItems = _getNavItems(user);

        return Scaffold(
          appBar: AppBar(
            title: Text(navItems[_currentIndex]['label'] as String),
            actions: [
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
                onPressed: () {},
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
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
              final path = navItems[index]['path'] as String;
              context.go(path);
            },
            destinations: navItems.map((item) {
              return NavigationDestination(
                icon: Icon(item['icon'] as IconData),
                selectedIcon: Icon(item['selectedIcon'] as IconData, color: AppColors.primary),
                label: item['label'] as String,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _getNavItems(UserModel? user) {
    final role = user?.primaryRole ?? 'supervisor';

    final items = <Map<String, dynamic>>[
      {
        'icon': Icons.inbox_outlined,
        'selectedIcon': Icons.inbox_rounded,
        'label': 'الوارد',
        'path': '/inbox',
      },
    ];

    if (role == 'admin') {
      items.addAll([
        {
          'icon': Icons.people_outline,
          'selectedIcon': Icons.people_rounded,
          'label': 'الطلاب',
          'path': '/students',
        },
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
          'icon': Icons.group_outlined,
          'selectedIcon': Icons.group_rounded,
          'label': 'الفريق',
          'path': '/users',
        },
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
      items.addAll([
        {
          'icon': Icons.search_outlined,
          'selectedIcon': Icons.search_rounded,
          'label': 'البحث',
          'path': '/tickets',
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
