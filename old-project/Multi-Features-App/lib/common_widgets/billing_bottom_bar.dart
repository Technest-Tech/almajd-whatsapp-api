import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/router/app_router.dart';

/// Bottom navigation bar for Billing and Reports section with 4 buttons
class BillingBottomBar extends StatelessWidget {
  final String currentRoute;

  const BillingBottomBar({
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
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavButton(
                context,
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard,
                label: 'لوحة المدفوعات',
                route: AppRouter.billings,
                isActive: currentRoute == AppRouter.billings || 
                         currentRoute.contains('/dashboard'),
              ),
              _buildNavButton(
                context,
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long,
                label: 'الفواتير التلقائية',
                route: '${AppRouter.billings}/auto',
                isActive: currentRoute.contains('/auto'),
              ),
              _buildNavButton(
                context,
                icon: Icons.description_outlined,
                activeIcon: Icons.description,
                label: 'الفواتير اليدوية',
                route: '${AppRouter.billings}/manual',
                isActive: currentRoute.contains('/manual'),
              ),
              _buildNavButton(
                context,
                icon: Icons.assessment_outlined,
                activeIcon: Icons.assessment,
                label: 'التقارير',
                route: '${AppRouter.billings}/reports',
                isActive: currentRoute.contains('/reports'),
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
              children: [
                Icon(
                  isActive ? activeIcon : icon,
                  color: isActive ? activeColor : inactiveColor,
                  size: 20,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isActive ? activeColor : inactiveColor,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
