import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/session_model.dart';

class SessionDetailScreen extends StatefulWidget {
  final int sessionId;
  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  SessionModel? _session;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  void _loadSession() {
    if (AuthBloc.demoMode) {
      final mocks = _demoSessions();
      final found = mocks.where((s) => s.id == widget.sessionId);
      if (found.isNotEmpty) setState(() => _session = found.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
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

  List<SessionModel> _demoSessions() {
    final now = DateTime.now();
    return [
      SessionModel(id: 1, title: 'القرآن الكريم', teacherName: 'أ. عبدالله المحمد', sessionDate: now, startTime: '08:00', endTime: '09:00', status: 'scheduled'),
      SessionModel(id: 2, title: 'الرياضيات', teacherName: 'أ. فاطمة الأحمد', sessionDate: now, startTime: '09:30', endTime: '10:30', status: 'scheduled'),
      SessionModel(id: 3, title: 'القرآن الكريم', teacherName: 'أ. عبدالله المحمد', sessionDate: now.subtract(const Duration(days: 1)), startTime: '08:00', endTime: '09:00', status: 'completed'),
      SessionModel(id: 4, title: 'اللغة العربية', teacherName: 'أ. خالد العتيبي', sessionDate: now.subtract(const Duration(days: 1)), startTime: '09:30', endTime: '10:30', status: 'completed'),
      SessionModel(id: 5, title: 'العلوم', teacherName: 'أ. نورة السعيد', sessionDate: now.subtract(const Duration(days: 2)), startTime: '10:00', endTime: '11:00', status: 'cancelled', cancellationReason: 'غياب المعلمة'),
      SessionModel(id: 6, title: 'حفظ القرآن', teacherName: 'أ. عبدالله المحمد', sessionDate: now.subtract(const Duration(days: 2)), startTime: '16:00', endTime: '17:30', status: 'completed'),
      SessionModel(id: 7, title: 'التجويد', teacherName: 'أ. عبدالله المحمد', sessionDate: now.add(const Duration(days: 1)), startTime: '08:00', endTime: '09:00', status: 'scheduled'),
      SessionModel(id: 8, title: 'تقوية رياضيات', teacherName: 'أ. فاطمة الأحمد', sessionDate: now.add(const Duration(days: 1)), startTime: '14:00', endTime: '15:30', status: 'scheduled'),
      SessionModel(id: 9, title: 'نحو وصرف', teacherName: 'أ. خالد العتيبي', sessionDate: now.subtract(const Duration(days: 3)), startTime: '09:00', endTime: '11:00', status: 'completed'),
      SessionModel(id: 10, title: 'مراجعة الحفظ', teacherName: 'أ. عبدالله المحمد', sessionDate: now.subtract(const Duration(days: 4)), startTime: '16:00', endTime: '17:30', status: 'cancelled', cancellationReason: 'عطلة رسمية'),
    ];
  }
}
