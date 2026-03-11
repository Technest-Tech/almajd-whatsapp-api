class ClassSessionModel {
  final int id;
  final int? scheduleEntryId;
  final int? studentId;
  final int? teacherId;
  final String? teacherName;
  final String? studentName;
  final String title;
  final DateTime sessionDate;
  final String startTime;
  final String endTime;
  final String status; // scheduled, completed, cancelled, rescheduled
  final String? cancellationReason;
  final DateTime? rescheduledDate;
  final String? rescheduledStartTime;
  final String? rescheduledEndTime;
  final String? attendanceStatus; // pending, teacher_joined, student_absent, both_joined, no_show

  const ClassSessionModel({
    required this.id,
    this.scheduleEntryId,
    this.studentId,
    this.teacherId,
    this.teacherName,
    this.studentName,
    required this.title,
    required this.sessionDate,
    required this.startTime,
    required this.endTime,
    this.status = 'scheduled',
    this.cancellationReason,
    this.rescheduledDate,
    this.rescheduledStartTime,
    this.rescheduledEndTime,
    this.attendanceStatus,
  });

  factory ClassSessionModel.fromJson(Map<String, dynamic> json) {
    return ClassSessionModel(
      id: json['id'],
      scheduleEntryId: json['schedule_entry_id'],
      studentId: json['student_id'],
      teacherId: json['teacher_id'],
      teacherName: json['teacher'] != null ? json['teacher']['name'] : null,
      studentName: json['student'] != null ? json['student']['name'] : null,
      title: json['title'] ?? '',
      sessionDate: DateTime.parse(json['session_date']),
      startTime: json['start_time'] ?? '00:00',
      endTime: json['end_time'] ?? '00:00',
      status: json['status'] ?? 'scheduled',
      cancellationReason: json['cancellation_reason'],
      rescheduledDate: json['rescheduled_date'] != null ? DateTime.tryParse(json['rescheduled_date']) : null,
      rescheduledStartTime: json['rescheduled_start_time'],
      rescheduledEndTime: json['rescheduled_end_time'],
      attendanceStatus: json['attendance_status'],
    );
  }

  bool get isScheduled => status == 'scheduled';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isRescheduled => status == 'rescheduled';

  /// Converts "HH:mm" or "HH:mm:ss" to 12-hour Arabic AM/PM format
  static String _to12hr(String hhmm) {
    try {
      final parts = hhmm.split(':');
      int hour = int.parse(parts[0]);
      final minute = parts[1].padLeft(2, '0');
      final period = hour < 12 ? 'ص' : 'م';
      hour = hour % 12;
      if (hour == 0) hour = 12;
      return '$hour:$minute $period';
    } catch (_) {
      return hhmm;
    }
  }

  String get startTime12h => _to12hr(startTime);
  String get endTime12h   => _to12hr(endTime);
  String get effectiveStartTime12h => _to12hr(effectiveStartTime);
  String get effectiveEndTime12h   => _to12hr(effectiveEndTime);

  String get statusDisplay {
    switch (status) {
      case 'scheduled': return 'مجدولة';
      case 'completed': return 'مكتملة';
      case 'cancelled': return 'ملغاة';
      case 'rescheduled': return 'مُعاد جدولتها';
      default: return status;
    }
  }

  String get dateDisplay {
    const days = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    final dayName = days[sessionDate.weekday - 1];
    return '$dayName ${sessionDate.day}/${sessionDate.month}';
  }

  String get effectiveStartTime => rescheduledStartTime ?? startTime;
  String get effectiveEndTime => rescheduledEndTime ?? endTime;
  DateTime get effectiveDate => rescheduledDate ?? sessionDate;

  String get effectiveDateDisplay {
    final d = effectiveDate;
    return '${d.day}/${d.month}/${d.year}';
  }
}
