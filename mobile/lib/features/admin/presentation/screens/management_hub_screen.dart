import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/api_service.dart';

class ManagementHubScreen extends StatefulWidget {
  const ManagementHubScreen({super.key});

  @override
  State<ManagementHubScreen> createState() => _ManagementHubScreenState();
}

class _ManagementHubScreenState extends State<ManagementHubScreen> {
  static const _items = [
    _HubItem(icon: Icons.calendar_today_rounded, label: 'التقويم', subtitle: 'الجدول والتذكيرات', path: '/calendar', color: Color(0xFF2196F3)),
    _HubItem(icon: Icons.calendar_month_rounded, label: 'الجداول', subtitle: 'إدارة جداول الطلاب', path: '/timetable', color: Color(0xFF26A69A)),
    _HubItem(icon: Icons.event_available_rounded, label: 'إدارة الحصص', subtitle: 'والمتابعة', path: '/classes', color: Color(0xFF42A5F5)),
    _HubItem(icon: Icons.shield_rounded, label: 'المشرفون', subtitle: 'إدارة المشرفين', path: '/supervisors', color: Color(0xFFAB47BC)),
    _HubItem(icon: Icons.insert_chart_outlined_rounded, label: 'أداء المشرفين', subtitle: 'التقارير والإحصائيات', path: '/supervisors_stats', color: Color(0xFF00A884)),
    _HubItem(icon: Icons.bar_chart_rounded, label: 'التقارير', subtitle: 'إحصائيات النظام', path: '/analytics', color: Color(0xFFEF5350)),
    _HubItem(icon: Icons.settings_rounded, label: 'إعدادات النظام', subtitle: 'الحساب والتفضيلات', path: '/settings', color: Color(0xFF78909C)),
  ];

  // ── Session Management State ─────────────────────────────────────────────
  bool _isGenerating = false;
  bool _isClearing = false;
  String? _lastAction;
  DateTime? _lastGeneratedAt;

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

        // Navigation Grid
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
            return _HubCard(item: item, onTap: () => context.go(item.path));
          },
        ),

        const SizedBox(height: 20),

        // ── Session Management Card ──────────────────────────────────────────
        _buildSessionManagementCard(context),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSessionManagementCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_month_rounded, size: 22, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('إدارة الجلسات', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      Text('توليد أو حذف جلسات التقويم', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (_lastGeneratedAt != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'آخر توليد ${_lastGeneratedAt!.hour.toString().padLeft(2, '0')}:${_lastGeneratedAt!.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),

            // Success status message
            if (_lastAction != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_lastAction!, style: const TextStyle(fontSize: 12, color: Colors.green)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Action Buttons Row
            Row(
              children: [
                // Generate Sessions
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_isGenerating || _isClearing) ? null : () => _generateSessions(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isGenerating
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      _isGenerating ? 'جاري التوليد...' : 'توليد الجلسات\n(3 أشهر)',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Clear All Sessions
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_isGenerating || _isClearing) ? null : () => _confirmClear(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isClearing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                        : const Icon(Icons.delete_sweep_rounded, size: 18),
                    label: Text(
                      _isClearing ? 'جاري الحذف...' : 'حذف جميع\nالجلسات',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateSessions(BuildContext context) async {
    setState(() { _isGenerating = true; _lastAction = null; });
    try {
      final api = ApiService();
      final response = await api.post('/v1/calendar/sessions/generate');
      final data = response.data as Map<String, dynamic>;
      final created = data['sessions_created'] ?? 0;
      final total = data['total_sessions'] ?? 0;
      if (mounted) {
        setState(() {
          _lastAction = 'تم توليد $created جلسة جديدة — الإجمالي: $total';
          _lastGeneratedAt = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل التوليد: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف', textAlign: TextAlign.right),
        content: const Text(
          'سيتم حذف جميع الجلسات القادمة والتذكيرات المعلقة.\nلا يمكن التراجع عن هذا الإجراء.',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف الكل', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() { _isClearing = true; _lastAction = null; });
    try {
      final api = ApiService();
      final response = await api.delete('/v1/calendar/sessions/clear-all');
      final data = response.data as Map<String, dynamic>;
      final deleted = data['deleted_sessions'] ?? 0;
      final reminders = data['deleted_reminders'] ?? 0;
      if (mounted) {
        setState(() {
          _lastAction = 'تم حذف $deleted جلسة و $reminders تذكير';
          _lastGeneratedAt = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحذف: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
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
