class SessionModel {
  final int id;
  final int? scheduleEntryId;
  final int? teacherId;
  final String? teacherName;
  final int? supervisorId;
  final String? supervisorName;
  final String title;
  final DateTime? sessionDate;
  final String? startTime;
  final String? endTime;
  final String status; // scheduled, completed, cancelled
  final String? cancellationReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SessionModel({
    required this.id,
    this.scheduleEntryId,
    this.teacherId,
    this.teacherName,
    this.supervisorId,
    this.supervisorName,
    required this.title,
    this.sessionDate,
    this.startTime,
    this.endTime,
    this.status = 'scheduled',
    this.cancellationReason,
    this.createdAt,
    this.updatedAt,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'],
      scheduleEntryId: json['schedule_entry_id'],
      teacherId: json['teacher_id'],
      teacherName: json['teacher'] != null ? json['teacher']['name'] : null,
      supervisorId: json['supervisor_id'],
      supervisorName: json['supervisor'] != null ? json['supervisor']['name'] as String? : null,
      title: json['title'] ?? '',
      sessionDate: json['session_date'] != null ? DateTime.tryParse(json['session_date']) : null,
      startTime: json['start_time'],
      endTime: json['end_time'],
      status: json['status'] ?? 'scheduled',
      cancellationReason: json['cancellation_reason'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }

  String get statusDisplay {
    switch (status) {
      case 'scheduled':
        return 'مجدولة';
      case 'coming':
        return 'قادمة';
      case 'pending':
        return 'معلّقة';
      case 'running':
        return 'جارية';
      case 'completed':
        return 'مكتملة';
      case 'cancelled':
        return 'ملغاة';
      case 'rescheduled':
        return 'مُعاد جدولتها';
      default:
        return status;
    }
  }

  String get dateDisplay {
    if (sessionDate == null) return '';
    return '${sessionDate!.day}/${sessionDate!.month}/${sessionDate!.year}';
  }

  String get timeDisplay {
    if (startTime == null || endTime == null) return '';
    return '$startTime — $endTime';
  }
}
