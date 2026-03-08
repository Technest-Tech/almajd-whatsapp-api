import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';


class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _loading = true;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // TODO: fetch analytics from API
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {
      _loading = false;
      _data = {};
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        setState(() => _loading = true);
        await _load();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Summary Stats ──
          _buildSectionTitle('نظرة عامة'),
          const SizedBox(height: 10),
          _buildStatGrid([
            _StatItem('الطلاب', '${_data['total_students']}', Icons.people_alt_outlined, AppColors.primary, '${_data['active_students']} نشط'),
            _StatItem('المعلمون', '${_data['total_teachers']}', Icons.school_outlined, const Color(0xFF42A5F5), null),
            _StatItem('الجداول', '${_data['total_schedules']}', Icons.calendar_today, const Color(0xFFAB47BC), '${_data['active_schedules']} نشط'),
            _StatItem('التذاكر المفتوحة', '${_data['open_tickets']}', Icons.confirmation_num_outlined, AppColors.amber, '${_data['resolved_tickets']} محلولة'),
          ]),

          const SizedBox(height: 24),

          // ── Sessions Stats ──
          _buildSectionTitle('الحصص'),
          const SizedBox(height: 10),
          _buildStatGrid([
            _StatItem('إجمالي الحصص', '${_data['total_sessions']}', Icons.event_note_outlined, AppColors.primary, null),
            _StatItem('مكتملة', '${_data['completed_sessions']}', Icons.check_circle_outline, AppColors.success, null),
            _StatItem('ملغاة', '${_data['cancelled_sessions']}', Icons.cancel_outlined, AppColors.coral, null),
          ]),

          const SizedBox(height: 24),

          // ── Reminders Stats ──
          _buildSectionTitle('التنبيهات'),
          const SizedBox(height: 10),
          _buildStatGrid([
            _StatItem('معلّقة', '${_data['pending_reminders']}', Icons.schedule_send, AppColors.amber, null),
            _StatItem('تم إرسالها', '${_data['sent_reminders']}', Icons.mark_email_read_outlined, AppColors.success, null),
          ]),

          const SizedBox(height: 24),

          // ── Session Completion Rate ──
          _buildSectionTitle('معدل إكمال الحصص'),
          const SizedBox(height: 10),
          _buildCompletionCard(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary));
  }

  Widget _buildStatGrid(List<_StatItem> items) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) {
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 42) / 2,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: item.color.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(item.icon, size: 18, color: item.color),
                    ),
                    const Spacer(),
                    Text(item.value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: item.color)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(item.label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                if (item.subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(item.subtitle!, style: TextStyle(color: item.color.withValues(alpha: 0.7), fontSize: 11)),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCompletionCard() {
    final total = (_data['total_sessions'] as int?) ?? 1;
    final completed = (_data['completed_sessions'] as int?) ?? 0;
    final rate = total > 0 ? (completed / total * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('نسبة الإكمال', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const Spacer(),
              Text('${rate.toStringAsFixed(1)}%', style: const TextStyle(color: AppColors.success, fontSize: 22, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rate / 100,
              minHeight: 8,
              backgroundColor: AppColors.darkCardElevated,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$completed مكتملة', style: const TextStyle(color: AppColors.success, fontSize: 12)),
              Text('${total - completed} متبقية', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  const _StatItem(this.label, this.value, this.icon, this.color, this.subtitle);
}
