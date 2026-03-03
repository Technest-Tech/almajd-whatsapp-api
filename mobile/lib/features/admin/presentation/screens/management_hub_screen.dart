import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';

class ManagementHubScreen extends StatelessWidget {
  const ManagementHubScreen({super.key});

  static const _items = [
    _HubItem(icon: Icons.calendar_month_rounded, label: 'الجداول', subtitle: 'إدارة جداول الطلاب', path: '/timetable', color: Color(0xFF26A69A)),
    _HubItem(icon: Icons.class_rounded, label: 'الحصص', subtitle: 'جلسات اليوم والقادمة', path: '/sessions', color: Color(0xFF42A5F5)),
    _HubItem(icon: Icons.notifications_active_rounded, label: 'التذكيرات', subtitle: 'إشعارات واتساب', path: '/reminders', color: Color(0xFFFFA726)),
    _HubItem(icon: Icons.group_rounded, label: 'المستخدمون', subtitle: 'مدراء ومشرفون', path: '/users', color: Color(0xFFAB47BC)),
    _HubItem(icon: Icons.bar_chart_rounded, label: 'التقارير', subtitle: 'إحصائيات النظام', path: '/analytics', color: Color(0xFFEF5350)),
    _HubItem(icon: Icons.settings_rounded, label: 'إعدادات النظام', subtitle: 'الحساب والتفضيلات', path: '/settings', color: Color(0xFF78909C)),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary.withValues(alpha: 0.25), AppColors.darkCard],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.dashboard_rounded, size: 28, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('لوحة الإدارة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    SizedBox(height: 4),
                    Text('إدارة جميع موارد الأكاديمية', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.15,
          ),
          itemCount: _items.length,
          itemBuilder: (context, index) {
            final item = _items[index];
            return _HubCard(item: item, onTap: () => context.push(item.path));
          },
        ),
      ],
    );
  }
}

class _HubItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final String path;
  final Color color;

  const _HubItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.path,
    required this.color,
  });
}

class _HubCard extends StatelessWidget {
  final _HubItem item;
  final VoidCallback onTap;

  const _HubCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: item.color.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, size: 26, color: item.color),
              ),
              const Spacer(),
              Text(
                item.label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                item.subtitle,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
