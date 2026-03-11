import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/class_session_model.dart';

class StudentClassesTab extends StatefulWidget {
  final List<ClassSessionModel> sessions;
  final VoidCallback onGenerate;
  final void Function(int sessionId, String action, {String? reason, DateTime? newDate, TimeOfDay? newStart, TimeOfDay? newEnd}) onAction;

  const StudentClassesTab({
    super.key,
    required this.sessions,
    required this.onGenerate,
    required this.onAction,
  });

  @override
  State<StudentClassesTab> createState() => _StudentClassesTabState();
}

class _StudentClassesTabState extends State<StudentClassesTab> {
  static const _statusColors = {
    'scheduled': Color(0xFF42A5F5),
    'completed': Color(0xFF26A69A),
    'cancelled': Color(0xFFEF5350),
    'rescheduled': Color(0xFFFFA726),
  };

  static const _statusIcons = {
    'scheduled': Icons.schedule,
    'completed': Icons.check_circle,
    'cancelled': Icons.cancel,
    'rescheduled': Icons.update,
  };

  @override
  Widget build(BuildContext context) {
    if (widget.sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.class_outlined, size: 64, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 12),
            const Text('لا توجد حصص لهذا الشهر', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('توليد الحصص من الجدول الأسبوعي', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: widget.onGenerate,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('توليد حصص الشهر'),
            ),
          ],
        ),
      );
    }

    // Group by week
    final grouped = <String, List<ClassSessionModel>>{};
    for (final s in widget.sessions) {
      final weekStart = s.sessionDate.subtract(Duration(days: s.sessionDate.weekday % 7));
      final key = '${weekStart.day}/${weekStart.month}';
      grouped.putIfAbsent(key, () => []).add(s);
    }

    // Stats
    final total = widget.sessions.length;
    final completed = widget.sessions.where((s) => s.isCompleted).length;
    final cancelled = widget.sessions.where((s) => s.isCancelled).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        // Stats header
        Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat('الكل', total, AppColors.primary),
                  _buildStat('مكتملة', completed, const Color(0xFF26A69A)),
                  _buildStat('ملغاة', cancelled, const Color(0xFFEF5350)),
                ],
              ),
            ),
        const SizedBox(height: 16),

        // Session cards
        ...widget.sessions.map(_buildSessionCard),
      ],
    );
  }

  Widget _buildStat(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _buildSessionCard(ClassSessionModel session) {
    final statusColor = _statusColors[session.status] ?? AppColors.textSecondary;
    final statusIcon = _statusIcons[session.status] ?? Icons.help;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border(right: BorderSide(color: statusColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: date + status
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary.withValues(alpha: 0.7)),
              const SizedBox(width: 6),
              Text(session.dateDisplay, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(session.statusDisplay, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Title + time
          Row(
            children: [
              Expanded(
                child: Text(session.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              Text('${session.effectiveStartTime12h} - ${session.effectiveEndTime12h}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),

          // Teacher
          if (session.teacherName != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(session.teacherName!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ],

          // Reschedule info
          if (session.isRescheduled) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFA726).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'نُقلت إلى: ${session.effectiveDateDisplay} (${session.effectiveStartTime12h})',
                style: const TextStyle(color: Color(0xFFFFA726), fontSize: 11),
              ),
            ),
          ],

          // Cancel reason
          if (session.isCancelled && session.cancellationReason != null) ...[
            const SizedBox(height: 6),
            Text('السبب: ${session.cancellationReason}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ],

          // Actions (only for scheduled sessions)
          if (session.isScheduled) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _actionButton('إتمام', Icons.check, const Color(0xFF26A69A), () {
                  widget.onAction(session.id, 'complete');
                }),
                const SizedBox(width: 8),
                _actionButton('إعادة جدولة', Icons.update, const Color(0xFFFFA726), () {
                  _showRescheduleDialog(session);
                }),
                const SizedBox(width: 8),
                _actionButton('إلغاء', Icons.close, const Color(0xFFEF5350), () {
                  _showCancelDialog(session);
                }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _showRescheduleDialog(ClassSessionModel session) async {
    final date = await showDatePicker(
      context: context,
      initialDate: session.sessionDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary, surface: AppColors.darkCard, onSurface: AppColors.textPrimary),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final start = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.tryParse(session.startTime.split(':')[0]) ?? 8, minute: 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary, surface: AppColors.darkCard, onSurface: AppColors.textPrimary),
        ),
        child: child!,
      ),
    );
    if (start == null || !mounted) return;

    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: start.hour + 1, minute: start.minute),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary, surface: AppColors.darkCard, onSurface: AppColors.textPrimary),
        ),
        child: child!,
      ),
    );
    if (end == null || !mounted) return;

    widget.onAction(session.id, 'reschedule', newDate: date, newStart: start, newEnd: end);
  }

  void _showCancelDialog(ClassSessionModel session) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        title: const Text('إلغاء الحصة'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'سبب الإلغاء (اختياري)',
            filled: true,
            fillColor: AppColors.darkBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('رجوع')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onAction(session.id, 'cancel', reason: controller.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );
  }
}
