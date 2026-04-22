import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:multi_features_app/l10n/app_localizations.dart';
import '../core/router/app_router.dart';

/// Modern bottom navigation bar with four main navigation buttons
class BottomActionBar extends StatelessWidget {
  final String currentRoute;

  const BottomActionBar({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, -6),
            spreadRadius: 0,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavButton(
                context,
                icon: Icons.analytics_outlined,
                activeIcon: Icons.analytics,
                label: AppLocalizations.of(context)?.dashboard ?? 'لوحة التحكم',
                route: AppRouter.usersAndCourses,
                isActive: currentRoute == AppRouter.usersAndCourses || 
                         (currentRoute.startsWith(AppRouter.usersAndCourses) && 
                          !currentRoute.contains('/students') && 
                          !currentRoute.contains('/teachers') && 
                          !currentRoute.contains('/salaries')),
              ),
              _buildNavButton(
                context,
                icon: Icons.people_outline,
                activeIcon: Icons.people,
                label: 'الطلاب',
                route: '${AppRouter.usersAndCourses}/students',
                isActive: currentRoute.contains('/students'),
              ),
              _buildNavButton(
                context,
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'المعلمون',
                route: '${AppRouter.usersAndCourses}/teachers',
                isActive: currentRoute.contains('/teachers'),
              ),
              _buildNavButton(
                context,
                icon: Icons.account_balance_wallet_outlined,
                activeIcon: Icons.account_balance_wallet,
                label: 'الرواتب',
                route: '${AppRouter.usersAndCourses}/salaries',
                isActive: currentRoute.contains('/salaries'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton(
    BuildContext context, {
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String route,
    required bool isActive,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final inactiveColor = Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.onSurface.withOpacity(0.7)
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.65);
    final activeColor = primaryColor;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (currentRoute != route) {
              context.go(route);
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            padding: const EdgeInsets.only(top: 2, bottom: 2, left: 4, right: 4),
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              gradient: isActive
                  ? LinearGradient(
                      colors: [
                        primaryColor.withOpacity(0.12),
                        primaryColor.withOpacity(0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              borderRadius: BorderRadius.circular(20),
              border: isActive
                  ? Border.all(
                      color: primaryColor.withOpacity(0.25),
                      width: 1.5,
                    )
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOutCubic,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isActive
                        ? primaryColor.withOpacity(0.12)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: animation,
                        child: child,
                      );
                    },
                    child: Icon(
                      isActive ? activeIcon : icon,
                      key: ValueKey(isActive),
                      color: isActive ? activeColor : inactiveColor,
                      size: isActive ? 18 : 16,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: isActive ? 9.5 : 9,
                    color: isActive ? activeColor : inactiveColor,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                    letterSpacing: 0.0,
                    height: 1.0,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
