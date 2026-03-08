import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/api/api_client.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../students/data/models/class_session_model.dart';

/// A premium classes-tracker screen for supervisors.
/// Shows today's classes grouped by time status: Current → Upcoming → Passed.
class ClassesTrackerScreen extends StatefulWidget {
  const ClassesTrackerScreen({super.key});

  @override
  State<ClassesTrackerScreen> createState() => _ClassesTrackerScreenState();
}

class _ClassesTrackerScreenState extends State<ClassesTrackerScreen> {
  final _apiClient = getIt<ApiClient>();

  List<ClassSessionModel> _sessions = [];
  bool _loading = true;
  String? _error;
  DateTime _selectedDate = DateTime.now();
  bool _showMineOnly = false;

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
      final dateStr =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
      final params = <String, dynamic>{'date': dateStr, 'per_page': 100};

      if (_showMineOnly) {
        // Get current user ID from stored auth
        try {
          final authState = context.read<AuthBloc>().state;
          if (authState is AuthAuthenticated && authState.user.id != null) {
            params['supervisor_id'] = authState.user.id;
          }
        } catch (_) {}
      }

      final response = await _apiClient.dio
          .get('/sessions', queryParameters: params);
      final List data = response.data['data'] ?? [];
      if (mounted) {
        setState(() {
          _sessions = data.map((j) => ClassSessionModel.fromJson(j)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'فشل تحميل الحصص';
          _loading = false;
        });
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────
  _TimeCategory _categorize(ClassSessionModel s) {
    final now = TimeOfDay.now();
    final start = _parseTime(s.effectiveStartTime);
    final end = _parseTime(s.effectiveEndTime);
    final nowMin = now.hour * 60 + now.minute;
    final startMin = start.hour * 60 + start.minute;
    final endMin = end.hour * 60 + end.minute;

    if (s.isCancelled) return _TimeCategory.passed;
    if (s.isCompleted) return _TimeCategory.passed;

    final today = DateTime.now();
    final isToday = _selectedDate.year == today.year &&
        _selectedDate.month == today.month &&
        _selectedDate.day == today.day;

    if (!isToday) {
      if (_selectedDate.isBefore(DateTime(today.year, today.month, today.day))) {
        return _TimeCategory.passed;
      }
      return _TimeCategory.upcoming;
    }

    if (nowMin >= startMin && nowMin < endMin) return _TimeCategory.current;
    if (nowMin < startMin) return _TimeCategory.upcoming;
    return _TimeCategory.passed;
  }

  TimeOfDay _parseTime(String t) {
    final parts = t.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  void _changeDate(int delta) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: delta)));
    _load();
  }

  Future<void> _sendReminder(int sessionId, String recipientType) async {
    try {
      await _apiClient.dio.post('/sessions/$sessionId/remind', data: {
        'recipient_type': recipientType,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(recipientType == 'student' ? 'تم إرسال التذكير للطالب ✅' : 'تم إرسال التذكير للمعلم ✅'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل إرسال التذكير'), backgroundColor: AppColors.coral, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _updateSessionStatus(int sessionId, String status) async {
    if (status == 'rescheduled') {
      _showRescheduleDialog(sessionId);
      return;
    }

    try {
      await _apiClient.dio.put('/sessions/$sessionId/status', data: {
        'status': status,
      });
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث الحالة ✅'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      debugPrint('Status update error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحديث الحالة: $e'), backgroundColor: AppColors.coral, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _showRescheduleDialog(int sessionId) async {
    DateTime? pickedDate;
    TimeOfDay? pickedStartTime;
    TimeOfDay? pickedEndTime;

    pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.darkCard,
          ),
        ),
        child: child!,
      ),
    );
    if (pickedDate == null || !mounted) return;

    pickedStartTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 16, minute: 0),
      helpText: 'وقت البداية',
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(primary: AppColors.primary, surface: AppColors.darkCard),
        ),
        child: child!,
      ),
    );
    if (pickedStartTime == null || !mounted) return;

    pickedEndTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: pickedStartTime.hour + 1, minute: pickedStartTime.minute),
      helpText: 'وقت النهاية',
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(primary: AppColors.primary, surface: AppColors.darkCard),
        ),
        child: child!,
      ),
    );
    if (pickedEndTime == null || !mounted) return;

    final dateStr = '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
    final startStr = '${pickedStartTime.hour.toString().padLeft(2, '0')}:${pickedStartTime.minute.toString().padLeft(2, '0')}';
    final endStr = '${pickedEndTime.hour.toString().padLeft(2, '0')}:${pickedEndTime.minute.toString().padLeft(2, '0')}';

    try {
      await _apiClient.dio.put('/sessions/$sessionId/status', data: {
        'status': 'rescheduled',
        'rescheduled_date': dateStr,
        'rescheduled_start_time': startStr,
        'rescheduled_end_time': endStr,
      });
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إعادة الجدولة ✅'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      debugPrint('Reschedule error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل إعادة الجدولة: $e'), backgroundColor: AppColors.coral, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Group sessions
    final current = <ClassSessionModel>[];
    final upcoming = <ClassSessionModel>[];
    final passed = <ClassSessionModel>[];
    for (final s in _sessions) {
      switch (_categorize(s)) {
        case _TimeCategory.current:
          current.add(s);
        case _TimeCategory.upcoming:
          upcoming.add(s);
        case _TimeCategory.passed:
          passed.add(s);
      }
    }

    return Column(
      children: [
        // ── Date Picker Bar ──
        _DateBar(
          date: _selectedDate,
          onPrev: () => _changeDate(-1),
          onNext: () => _changeDate(1),
          onPick: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2024),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              setState(() => _selectedDate = picked);
              _load();
            }
          },
        ),

        // ── Filter Toggle + Summary Chips ──
        if (!_loading && _error == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              children: [
                // Mine / All toggle
                Row(
                  children: [
                    _FilterChip(
                      label: 'الكل',
                      isSelected: !_showMineOnly,
                      onTap: () {
                        setState(() => _showMineOnly = false);
                        _load();
                      },
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'حصصي',
                      isSelected: _showMineOnly,
                      onTap: () {
                        setState(() => _showMineOnly = true);
                        _load();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _SummaryChip(
                      icon: Icons.play_circle_fill_rounded,
                      label: 'جارية',
                      count: current.length,
                      color: const Color(0xFF00E676),
                    ),
                    const SizedBox(width: 8),
                    _SummaryChip(
                      icon: Icons.schedule_rounded,
                      label: 'قادمة',
                      count: upcoming.length,
                      color: const Color(0xFF448AFF),
                    ),
                    const SizedBox(width: 8),
                    _SummaryChip(
                      icon: Icons.check_circle_rounded,
                      label: 'منتهية',
                      count: passed.length,
                      color: const Color(0xFF8696A0),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // ── Content ──
        Expanded(
          child: _loading
              ? _buildShimmer()
              : _error != null
                  ? _buildError()
                  : _sessions.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                            children: [
                              if (current.isNotEmpty) ...[
                                _SectionHeader(
                                  title: 'الحصص الجارية الآن',
                                  icon: Icons.play_circle_fill_rounded,
                                  color: const Color(0xFF00E676),
                                ),
                                ...current.map((s) => _SessionCard(
                                      session: s,
                                      category: _TimeCategory.current,
                                      onRemindStudent: () => _sendReminder(s.id, 'student'),
                                      onRemindTeacher: () => _sendReminder(s.id, 'teacher'),
                                      onStatusChange: (status) => _updateSessionStatus(s.id, status),
                                    )),
                                const SizedBox(height: 12),
                              ],
                              if (upcoming.isNotEmpty) ...[
                                _SectionHeader(
                                  title: 'الحصص القادمة',
                                  icon: Icons.schedule_rounded,
                                  color: const Color(0xFF448AFF),
                                ),
                                ...upcoming.map((s) => _SessionCard(
                                      session: s,
                                      category: _TimeCategory.upcoming,
                                      onRemindStudent: () => _sendReminder(s.id, 'student'),
                                      onRemindTeacher: () => _sendReminder(s.id, 'teacher'),
                                      onStatusChange: (status) => _updateSessionStatus(s.id, status),
                                    )),
                                const SizedBox(height: 12),
                              ],
                              if (passed.isNotEmpty) ...[
                                _SectionHeader(
                                  title: 'الحصص المنتهية',
                                  icon: Icons.check_circle_rounded,
                                  color: const Color(0xFF8696A0),
                                ),
                                ...passed.map((s) => _SessionCard(
                                      session: s,
                                      category: _TimeCategory.passed,
                                      onRemindStudent: () => _sendReminder(s.id, 'student'),
                                      onRemindTeacher: () => _sendReminder(s.id, 'teacher'),
                                      onStatusChange: (status) => _updateSessionStatus(s.id, status),
                                    )),
                              ],
                            ],
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildShimmer() => Shimmer.fromColors(
        baseColor: AppColors.darkCard,
        highlightColor: AppColors.darkCardElevated,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          itemCount: 5,
          itemBuilder: (_, __) => Container(
            height: 100,
            margin: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );

  Widget _buildError() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.coral),
            const SizedBox(height: 16),
            Text(_error!,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_rounded,
                size: 80, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            const Text('لا توجد حصص لهذا اليوم',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 18)),
            const SizedBox(height: 8),
            const Text('اختر يوماً آخر أو أنشئ حصصاً جديدة',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

enum _TimeCategory { current, upcoming, passed }

// ── Date Bar ─────────────────────────────────────────────────────────────────

class _DateBar extends StatelessWidget {
  final DateTime date;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPick;

  const _DateBar(
      {required this.date,
      required this.onPrev,
      required this.onNext,
      required this.onPick});

  String _label(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sel = DateTime(d.year, d.month, d.day);
    if (sel == today) return 'اليوم';
    if (sel == today.add(const Duration(days: 1))) return 'غداً';
    if (sel == today.subtract(const Duration(days: 1))) return 'أمس';

    const days = [
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد'
    ];
    return '${days[d.weekday - 1]} ${d.day}/${d.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.primary.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.primary),
            onPressed: onPrev,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: GestureDetector(
              onTap: onPick,
              child: Column(
                children: [
                  Text(
                    _label(date),
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15),
                  ),
                  Text(
                    '${date.day}/${date.month}/${date.year}',
                    style: TextStyle(
                      color: AppColors.primary.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.primary),
            onPressed: onNext,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ── Filter Chip Widget ───────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.darkCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.textSecondary.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ── Summary Chip Widget ──────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _SummaryChip(
      {required this.icon,
      required this.label,
      required this.count,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w900, fontSize: 18),
            ),
            Text(
              label,
              style: TextStyle(
                  color: color.withValues(alpha: 0.8), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionHeader(
      {required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
              child: Container(
                  height: 1,
                  color: color.withValues(alpha: 0.15))),
        ],
      ),
    );
  }
}

// ── Session Card ─────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final ClassSessionModel session;
  final _TimeCategory category;
  final VoidCallback? onRemindStudent;
  final VoidCallback? onRemindTeacher;
  final ValueChanged<String>? onStatusChange;

  const _SessionCard({
    required this.session,
    required this.category,
    this.onRemindStudent,
    this.onRemindTeacher,
    this.onStatusChange,
  });

  Color get _accentColor => switch (category) {
        _TimeCategory.current => const Color(0xFF00E676),
        _TimeCategory.upcoming => const Color(0xFF448AFF),
        _TimeCategory.passed => const Color(0xFF8696A0),
      };

  IconData get _statusIcon {
    switch (session.status) {
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      case 'rescheduled':
        return Icons.update;
      default:
        return category == _TimeCategory.current
            ? Icons.play_circle_fill_rounded
            : category == _TimeCategory.upcoming
                ? Icons.schedule
                : Icons.check_circle_outline;
    }
  }

  Color get _statusColor {
    switch (session.status) {
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.coral;
      case 'rescheduled':
        return AppColors.amber;
      default:
        return _accentColor;
    }
  }

  String get _statusLabel {
    switch (session.status) {
      case 'completed':
        return 'مكتملة';
      case 'cancelled':
        return 'ملغاة';
      case 'rescheduled':
        return 'مُعاد جدولتها';
      default:
        if (category == _TimeCategory.current) return 'جارية الآن';
        if (category == _TimeCategory.upcoming) return 'قادمة';
        return 'انتهت';
    }
  }

  /// Convert 24h time string "HH:mm" to 12h "h:mm AM/PM"
  String _to12Hour(String time24) {
    final parts = time24.split(':');
    int hour = int.parse(parts[0]);
    final minute = parts[1].length >= 2 ? parts[1].substring(0, 2) : parts[1];
    final period = hour >= 12 ? 'PM' : 'AM';
    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour -= 12;
    }
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          right: BorderSide(
            color: _accentColor,
            width: category == _TimeCategory.current ? 4 : 3,
          ),
        ),
        boxShadow: category == _TimeCategory.current
            ? [
                BoxShadow(
                    color: _accentColor.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 2))
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: student name + status
            Row(
              children: [
                Icon(Icons.person_rounded,
                    size: 16,
                    color: category == _TimeCategory.passed
                        ? AppColors.textSecondary
                        : AppColors.primary),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    session.studentName ?? 'طالب غير محدد',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: category == _TimeCategory.passed
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: category == _TimeCategory.current
                        ? Border.all(
                            color: _statusColor.withValues(alpha: 0.4))
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon, size: 12, color: _statusColor),
                      const SizedBox(width: 3),
                      Text(
                        _statusLabel,
                        style: TextStyle(
                            color: _statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Info row: course name, teacher
            Row(
              children: [
                // Course name (title)
                Icon(Icons.menu_book_rounded,
                    size: 14,
                    color: AppColors.textSecondary
                        .withValues(alpha: 0.7)),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    session.title,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                // Teacher
                if (session.teacherName != null) ...[
                  Icon(Icons.school_rounded,
                      size: 14,
                      color: AppColors.textSecondary
                          .withValues(alpha: 0.7)),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      session.teacherName!,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Time + date row
            Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 14, color: _accentColor.withValues(alpha: 0.8)),
                const SizedBox(width: 4),
                Text(
                  '${_to12Hour(session.effectiveStartTime)} — ${_to12Hour(session.effectiveEndTime)}',
                  style: TextStyle(
                    color: _accentColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.calendar_today_rounded,
                    size: 12, color: AppColors.textSecondary.withValues(alpha: 0.6)),
                const SizedBox(width: 3),
                Text(
                  session.effectiveDateDisplay,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                if (session.isRescheduled) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('تم التأجيل',
                        style: TextStyle(
                            color: AppColors.amber,
                            fontSize: 9,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),

            // Attendance status badge
            if (session.attendanceStatus != null && session.attendanceStatus != 'pending') ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _attendanceColor(session.attendanceStatus!).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_attendanceIcon(session.attendanceStatus!), size: 13, color: _attendanceColor(session.attendanceStatus!)),
                    const SizedBox(width: 4),
                    Text(_attendanceLabel(session.attendanceStatus!),
                        style: TextStyle(color: _attendanceColor(session.attendanceStatus!), fontSize: 10, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],

            // Action buttons
            const SizedBox(height: 8),
            Row(
              children: [
                _ActionButton(
                  icon: Icons.person_rounded,
                  label: 'تذكير الطالب',
                  color: const Color(0xFF448AFF),
                  onTap: onRemindStudent,
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.school_rounded,
                  label: 'تذكير المعلم',
                  color: const Color(0xFFAB47BC),
                  onTap: onRemindTeacher,
                ),
                const Spacer(),
                // Status menu
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                  padding: EdgeInsets.zero,
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'running', child: Row(children: [Icon(Icons.play_arrow, size: 16, color: Color(0xFF00E676)), SizedBox(width: 6), Text('جارية')])),
                    const PopupMenuItem(value: 'completed', child: Row(children: [Icon(Icons.check_circle, size: 16, color: Color(0xFF448AFF)), SizedBox(width: 6), Text('مكتملة')])),
                    const PopupMenuItem(value: 'cancelled', child: Row(children: [Icon(Icons.cancel, size: 16, color: Color(0xFFEF5350)), SizedBox(width: 6), Text('ملغاة')])),
                    const PopupMenuItem(value: 'pending', child: Row(children: [Icon(Icons.schedule, size: 16, color: Color(0xFFFFB74D)), SizedBox(width: 6), Text('معلّقة')])),
                    const PopupMenuItem(value: 'scheduled', child: Row(children: [Icon(Icons.event, size: 16, color: Color(0xFF8696A0)), SizedBox(width: 6), Text('مجدولة')])),
                    const PopupMenuItem(value: 'rescheduled', child: Row(children: [Icon(Icons.calendar_month, size: 16, color: Color(0xFF26C6DA)), SizedBox(width: 6), Text('إعادة الجدولة')])),
                  ],
                  onSelected: onStatusChange,
                ),
              ],
            ),

            // Cancellation reason
            if (session.isCancelled && session.cancellationReason != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 13, color: AppColors.coral),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      session.cancellationReason!,
                      style: const TextStyle(
                          color: AppColors.coral, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _attendanceColor(String s) => switch (s) {
    'both_joined' => AppColors.success,
    'teacher_joined' => AppColors.amber,
    'student_absent' => AppColors.coral,
    'no_show' => AppColors.coral,
    _ => AppColors.textSecondary,
  };

  IconData _attendanceIcon(String s) => switch (s) {
    'both_joined' => Icons.groups_rounded,
    'teacher_joined' => Icons.person_rounded,
    'student_absent' => Icons.person_off_rounded,
    'no_show' => Icons.warning_amber_rounded,
    _ => Icons.help_outline,
  };

  String _attendanceLabel(String s) => switch (s) {
    'both_joined' => 'الجميع حاضر',
    'teacher_joined' => 'المعلم حاضر فقط',
    'student_absent' => 'الطالب غائب',
    'no_show' => 'لم يحضر أحد',
    _ => s,
  };
}

// ── Action Button ────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
