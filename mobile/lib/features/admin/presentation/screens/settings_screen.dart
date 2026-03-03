import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Account Section ──
        _buildSectionTitle('الحساب'),
        const SizedBox(height: 8),
        _buildSettingsCard([
          _SettingsTile(
            icon: Icons.person_outline,
            title: 'الملف الشخصي',
            subtitle: 'تعديل الاسم والبريد الإلكتروني',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.lock_outline,
            title: 'تغيير كلمة المرور',
            subtitle: 'تحديث كلمة المرور',
            onTap: () {},
          ),
        ]),

        const SizedBox(height: 20),

        // ── Notifications Section ──
        _buildSectionTitle('الإشعارات'),
        const SizedBox(height: 8),
        _buildSettingsCard([
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'إشعارات التطبيق',
            subtitle: 'تفعيل أو تعطيل الإشعارات',
            trailing: Switch(
              value: true,
              onChanged: (_) {},
              activeThumbColor: AppColors.primary,
            ),
          ),
          _SettingsTile(
            icon: Icons.message_outlined,
            title: 'إشعارات واتساب',
            subtitle: 'إرسال التنبيهات عبر واتساب',
            trailing: Switch(
              value: true,
              onChanged: (_) {},
              activeThumbColor: AppColors.primary,
            ),
          ),
        ]),

        const SizedBox(height: 20),

        // ── Appearance Section ──
        _buildSectionTitle('المظهر'),
        const SizedBox(height: 8),
        _buildSettingsCard([
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'الوضع الداكن',
            subtitle: 'مفعّل دائماً',
            trailing: Switch(
              value: true,
              onChanged: (_) {},
              activeThumbColor: AppColors.primary,
            ),
          ),
          _SettingsTile(
            icon: Icons.text_fields,
            title: 'حجم الخط',
            subtitle: 'متوسط',
            onTap: () {},
          ),
        ]),

        const SizedBox(height: 20),

        // ── System Section ──
        _buildSectionTitle('النظام'),
        const SizedBox(height: 8),
        _buildSettingsCard([
          _SettingsTile(
            icon: Icons.storage_outlined,
            title: 'التخزين المؤقت',
            subtitle: 'مسح البيانات المؤقتة',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'عن التطبيق',
            subtitle: 'الإصدار 1.0.0',
            onTap: () {},
          ),
        ]),

        const SizedBox(height: 20),

        // ── Danger Zone ──
        Center(
          child: TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.logout, color: AppColors.coral),
            label: const Text('تسجيل الخروج', style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.w600)),
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary));
  }

  Widget _buildSettingsCard(List<_SettingsTile> tiles) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: tiles.asMap().entries.map((entry) {
          final index = entry.key;
          final tile = entry.value;
          return Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(tile.icon, size: 20, color: AppColors.primary),
                ),
                title: Text(tile.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                subtitle: Text(tile.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                trailing: tile.trailing ?? const Icon(Icons.chevron_left, color: AppColors.textSecondary, size: 20),
                onTap: tile.onTap,
              ),
              if (index < tiles.length - 1)
                Divider(height: 1, indent: 56, color: AppColors.darkCardElevated.withValues(alpha: 0.5)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SettingsTile {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });
}
