import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/admin_repository.dart';

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

        // ── WhatsApp Number Section ──
        _buildSectionTitle('رقم واتساب النشط'),
        const SizedBox(height: 8),
        const _WhatsAppNumberSection(),

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

/// Lets an admin pick which Wasender number sends AND receives everything
/// (reminders, polls, inbox). Exactly one is active at a time.
class _WhatsAppNumberSection extends StatefulWidget {
  const _WhatsAppNumberSection();

  @override
  State<_WhatsAppNumberSection> createState() => _WhatsAppNumberSectionState();
}

class _WhatsAppNumberSectionState extends State<_WhatsAppNumberSection> {
  final _repo = getIt<AdminRepository>();

  bool _loading = true;
  bool _switching = false;
  String? _error;
  String _active = 'primary';
  List<Map<String, dynamic>> _options = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.getWhatsAppNumber();
      setState(() {
        _active = (data['active'] ?? 'primary') as String;
        _options = List<Map<String, dynamic>>.from(data['options'] ?? const []);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'تعذّر تحميل الرقم النشط';
        _loading = false;
      });
    }
  }

  Future<void> _switchTo(Map<String, dynamic> option) async {
    final session = option['session'] as String;
    final number = (option['number'] as String?) ?? '';
    if (session == _active || _switching) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        title: const Text('تبديل الرقم النشط', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'سيتم إرسال واستقبال كل التذكيرات والرسائل من الرقم $number. هل تريد المتابعة؟',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _switching = true);
    try {
      final data = await _repo.setWhatsAppNumber(session);
      setState(() {
        _active = (data['active'] ?? session) as String;
        _options = List<Map<String, dynamic>>.from(data['options'] ?? _options);
        _switching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تفعيل الرقم $number'), backgroundColor: AppColors.primary),
        );
      }
    } catch (e) {
      setState(() => _switching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل تبديل الرقم'), backgroundColor: AppColors.coral),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
            )
          : _error != null
              ? ListTile(
                  leading: const Icon(Icons.error_outline, color: AppColors.coral),
                  title: Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  trailing: TextButton(onPressed: _load, child: const Text('إعادة')),
                )
              : Column(
                  children: _options.asMap().entries.map((entry) {
                    final index = entry.key;
                    final option = entry.value;
                    final session = option['session'] as String;
                    final number = (option['number'] as String?) ?? '';
                    final configured = (option['configured'] as bool?) ?? false;
                    final isActive = session == _active;
                    final label = session == 'old' ? 'الرقم القديم (015)' : 'الرقم الجديد (012)';

                    return Column(
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.phone_android, size: 20, color: AppColors.primary),
                          ),
                          title: Text(label,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          subtitle: Text(
                            number.isEmpty ? 'غير مهيأ' : number,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          trailing: isActive
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text('نشط',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                )
                              : (_switching
                                  ? const SizedBox(
                                      width: 18, height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                                  : const Icon(Icons.radio_button_unchecked, color: AppColors.textSecondary, size: 20)),
                          onTap: (isActive || !configured || _switching) ? null : () => _switchTo(option),
                          enabled: configured,
                        ),
                        if (index < _options.length - 1)
                          Divider(height: 1, indent: 56, color: AppColors.darkCardElevated.withValues(alpha: 0.5)),
                      ],
                    );
                  }).toList(),
                ),
    );
  }
}
