import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

import '../../data/models/session_model.dart';
import '../../data/session_repository.dart';
import '../../../../core/di/injection.dart';

class SessionDetailScreen extends StatefulWidget {
  final int sessionId;
  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  SessionModel? _session;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  void _loadSession() async {
    try {
      final repo = getIt<SessionRepository>();
      final session = await repo.getSession(widget.sessionId);
      if (mounted) {
        setState(() {
          _session = session;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل تحميل بيانات الحصة')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الحصة')),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final session = _session!;
    final statusColor = _statusColor(session.status);

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الحصة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_statusIcon(session.status), size: 32, color: statusColor),
                ),
                const SizedBox(height: 12),
                Text(
                  session.title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    session.statusDisplay,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Info Cards ──
          _buildInfoRow(Icons.person_outline, 'المعلم', session.teacherName ?? 'غير محدد'),
          _buildInfoRow(Icons.calendar_today_outlined, 'التاريخ', session.dateDisplay),
          if (session.timeDisplay.isNotEmpty)
            _buildInfoRow(Icons.access_time_outlined, 'الوقت', session.timeDisplay),
          if (session.cancellationReason != null)
            _buildInfoRow(Icons.info_outline, 'سبب الإلغاء', session.cancellationReason!, valueColor: AppColors.coral),

          const SizedBox(height: 28),

          // ── Actions ──
          if (session.status == 'scheduled') ...[
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _updateStatus('completed'),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('تم إكمال الحصة'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _showCancelDialog(),
                icon: const Icon(Icons.cancel_outlined, color: AppColors.coral),
                label: const Text('إلغاء الحصة', style: TextStyle(color: AppColors.coral)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.coral)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const Spacer(),
          Text(value, style: TextStyle(color: valueColor ?? AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

  void _updateStatus(String status) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(status == 'completed' ? 'تم تسجيل إكمال الحصة' : 'تم إلغاء الحصة'),
        backgroundColor: status == 'completed' ? AppColors.success : AppColors.coral,
      ),
    );
    Navigator.pop(context);
  }

  void _showCancelDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        title: const Text('إلغاء الحصة'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'سبب الإلغاء',
            hintText: 'أدخل سبب الإلغاء...',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تراجع')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateStatus('cancelled');
            },
            child: const Text('تأكيد الإلغاء', style: TextStyle(color: AppColors.coral)),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'scheduled':
        return AppColors.amber;
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.coral;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'scheduled':
        return Icons.schedule;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.circle;
    }
  }

}
