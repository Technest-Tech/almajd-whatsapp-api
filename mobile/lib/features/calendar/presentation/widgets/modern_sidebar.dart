import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/router/app_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class ModernSidebar extends StatelessWidget {
  final String currentRoute;
  final VoidCallback? onClose;

  const ModernSidebar({
    super.key,
    required this.currentRoute,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10, // Reduced from 20
            offset: const Offset(-2, 0),
            spreadRadius: 1, // Reduced from 2
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          RepaintBoundary(
            child: Container(
              padding: const EdgeInsets.all(AppSizes.spaceLg),
              decoration: BoxDecoration(
                gradient: AppColors.purpleGradient,
              ),
              child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  color: Colors.white,
                  size: AppSizes.iconLg,
                ),
                const SizedBox(width: AppSizes.spaceMd),
                const Expanded(
                  child: Text(
                    'التقويم',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (onClose != null)
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onClose,
                  ),
              ],
            ),
          ),
          ),

          // Navigation Menu - Scrollable
          Expanded(
            child: RepaintBoundary(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceMd),
                children: [
                  _buildNavItem(
                    context,
                    icon: Icons.calendar_view_month_rounded,
                    label: 'عرض التقويم',
                    route: AppRouter.calendar,
                    isActive: currentRoute == AppRouter.calendar,
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.notifications_active_rounded,
                    label: 'التذكيرات',
                    route: '${AppRouter.calendar}/reminders',
                    isActive: currentRoute.contains('/reminders'),
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.people_rounded,
                    label: 'المعلمون والجداول',
                    route: '${AppRouter.calendar}/teachers',
                    isActive: currentRoute.contains('/teachers'),
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.pause_circle_outline_rounded,
                    label: 'توقفات الطلاب',
                    route: '${AppRouter.calendar}/student-stops',
                    isActive: currentRoute.contains('/student-stops'),
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.flag_rounded,
                    label: 'دول الطلاب',
                    route: '${AppRouter.calendar}/student-countries',
                    isActive: currentRoute.contains('/student-countries'),
                  ),
                ],
              ),
            ),
          ),

          // Exit/Logout Button (Role-based)
          RepaintBoundary(
            child: Container(
            padding: const EdgeInsets.all(AppSizes.spaceMd),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppColors.textTertiary.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, authState) {
                final isCalendarManagerOnly = authState is AuthAuthenticated &&
                    authState.user.roles.contains('calendar_manager') &&
                    !authState.user.roles.contains('admin');

                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppSizes.spaceMd,
                    vertical: AppSizes.spaceXs,
                  ),
                  decoration: BoxDecoration(
                    color: isCalendarManagerOnly
                        ? Colors.red.withOpacity(0.1)
                        : AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    border: Border.all(
                      color: isCalendarManagerOnly ? Colors.red : AppColors.primary,
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      isCalendarManagerOnly ? Icons.logout_rounded : Icons.close_rounded,
                      color: isCalendarManagerOnly ? Colors.red : AppColors.primary,
                    ),
                    title: Text(
                      isCalendarManagerOnly ? 'تسجيل الخروج' : 'العودة للوحة التحكم',
                      style: TextStyle(
                        color: isCalendarManagerOnly ? Colors.red : AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      if (isCalendarManagerOnly) {
                        context.read<AuthBloc>().add(AuthLogoutRequested());
                        context.go('/login');
                      } else {
                        context.go('/management');
                      }
                      // Close sidebar after navigation
                      if (onClose != null) {
                        onClose!();
                      }
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                  ),
                );
              },
            ),
          ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    required bool isActive,
  }) {
    return RepaintBoundary(
      child: Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSizes.spaceMd,
        vertical: AppSizes.spaceXs,
      ),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: isActive
            ? Border.all(color: AppColors.primary, width: 1)
            : null,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isActive ? AppColors.primary : AppColors.textSecondary,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isActive ? AppColors.primary : AppColors.textPrimary,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () {
          if (currentRoute != route) {
            context.go(route);
            // Close sidebar after navigation
            if (onClose != null) {
              onClose!();
            }
          }
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      ),
    ),
    );
  }
}
