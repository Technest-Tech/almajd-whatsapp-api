import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';

class ClientSidebarItem {
  final String label;
  final IconData icon;
  final String route;
  final bool isActive;

  ClientSidebarItem({
    required this.label,
    required this.icon,
    required this.route,
    this.isActive = false,
  });
}

class ClientSidebar extends StatelessWidget {
  final String userEmail;
  final String currentRoute;
  final VoidCallback onLogout;
  final VoidCallback? onClose;

  const ClientSidebar({
    super.key,
    required this.userEmail,
    required this.currentRoute,
    required this.onLogout,
    this.onClose,
  });

  static final List<ClientSidebarItem> _menuItems = [
    ClientSidebarItem(
      label: 'لوحة التحكم',
      icon: Icons.dashboard_rounded,
      route: '/client/dashboard',
    ),
    ClientSidebarItem(
      label: 'إدارة الغرف',
      icon: Icons.meeting_room_rounded,
      route: '/client/rooms',
    ),
    ClientSidebarItem(
      label: 'الاشتراك',
      icon: Icons.credit_card_rounded,
      route: '/client/subscription',
    ),
    ClientSidebarItem(
      label: 'الإعدادات',
      icon: Icons.settings_rounded,
      route: '/client/settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 20,
              offset: const Offset(-2, 0),
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            _buildHeader(context),
            
            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceMd),
                children: _menuItems.map((item) {
                  final isActive = currentRoute == item.route;
                  return _buildMenuItem(context, item, isActive);
                }).toList(),
              ),
            ),

            // Logout Button
            _buildLogoutButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spaceLg),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.spaceSm),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: const Icon(
              Icons.video_call_rounded,
              color: Colors.white,
              size: AppSizes.iconMd,
            ),
          ),
          const SizedBox(width: AppSizes.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'لوحة تحكم العميل',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: AppSizes.spaceXs),
                Text(
                  userEmail,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
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
    );
  }

  Widget _buildMenuItem(BuildContext context, ClientSidebarItem item, bool isActive) {
    return Container(
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
            ? Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 1,
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (currentRoute != item.route) {
              context.go(item.route);
              if (onClose != null) {
                onClose!();
              }
            }
          },
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.spaceMd,
              vertical: AppSizes.spaceMd,
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                  size: AppSizes.iconSm,
                ),
                const SizedBox(width: AppSizes.spaceMd),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: isActive
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spaceMd),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppColors.border,
            width: 1,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onLogout,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.spaceMd,
              vertical: AppSizes.spaceMd,
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.logout_rounded,
                  color: AppColors.error,
                  size: AppSizes.iconSm,
                ),
                SizedBox(width: AppSizes.spaceMd),
                Expanded(
                  child: Text(
                    'تسجيل الخروج',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
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
