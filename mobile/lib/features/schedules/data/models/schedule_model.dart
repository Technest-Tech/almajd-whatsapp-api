class ScheduleModel {
  final int id;
  final int? studentId;
  final String? studentName;
  final String name;
  final String? description;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final List<ScheduleEntryModel> entries;
  final int entryCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ScheduleModel({
    required this.id,
    this.studentId,
    this.studentName,
    required this.name,
    this.description,
    this.startDate,
    this.endDate,
    this.isActive = true,
    this.entries = const [],
    this.entryCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    return ScheduleModel(
      id: json['id'],
      studentId: json['student_id'],
      studentName: json['student']?['name'],
      name: json['name'] ?? '',
      description: json['description'],
      startDate: json['start_date'] != null ? DateTime.tryParse(json['start_date']) : null,
      endDate: json['end_date'] != null ? DateTime.tryParse(json['end_date']) : null,
      isActive: json['is_active'] ?? true,
      entries: json['entries'] != null
          ? (json['entries'] as List).map((e) => ScheduleEntryModel.fromJson(e)).toList()
          : [],
      entryCount: json['entries_count'] ?? (json['entries'] != null ? (json['entries'] as List).length : 0),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'start_date': startDate?.toIso8601String().split('T').first,
    'end_date': endDate?.toIso8601String().split('T').first,
    'is_active': isActive,
  };

  String get statusDisplay => isActive ? 'نشط' : 'متوقف';

  String get dateRangeDisplay {
    if (startDate == null || endDate == null) return 'مستمر';
    final s = '${startDate!.day}/${startDate!.month}/${startDate!.year}';
    final e = '${endDate!.day}/${endDate!.month}/${endDate!.year}';
    return '$s — $e';
  }
}

class ScheduleEntryModel {
  final int id;
  final int? scheduleId;
  final int? teacherId;
  final String? teacherName;
  final String title;
  final int dayOfWeek; // 0=Sun, 1=Mon, ..., 6=Sat
  final String startTime; // "HH:mm"
  final String endTime;
  final String recurrence; // weekly, biweekly, once
  final String? notes;
  final bool isActive;

  const ScheduleEntryModel({
    required this.id,
    this.scheduleId,
    this.teacherId,
    this.teacherName,
    required this.title,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.recurrence = 'weekly',
    this.notes,
    this.isActive = true,
  });

  factory ScheduleEntryModel.fromJson(Map<String, dynamic> json) {
    return ScheduleEntryModel(
      id: json['id'],
      scheduleId: json['schedule_id'] ?? 0,
      teacherId: json['teacher_id'],
      teacherName: json['teacher'] != null ? json['teacher']['name'] : null,
      title: json['title'] ?? '',
      dayOfWeek: json['day_of_week'] ?? 0,
      startTime: json['start_time'] ?? '00:00',
      endTime: json['end_time'] ?? '00:00',
      recurrence: json['recurrence'] ?? 'weekly',
      notes: json['notes'],
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'teacher_id': teacherId,
    'title': title,
    'day_of_week': dayOfWeek,
    'start_time': startTime,
    'end_time': endTime,
    'recurrence': recurrence,
    'notes': notes,
    'is_active': isActive,
  };

  String get dayDisplay {
    const days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    if (dayOfWeek >= 0 && dayOfWeek < 7) return days[dayOfWeek];
    return '';
  }

  /// Converts "HH:mm" or "HH:mm:ss" to 12-hour AM/PM format
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

  String get timeDisplay => '${_to12hr(startTime)} — ${_to12hr(endTime)}';

  String get recurrenceDisplay {
    switch (recurrence) {
      case 'weekly':
        return 'أسبوعياً';
      case 'biweekly':
        return 'كل أسبوعين';
      case 'once':
        return 'مرة واحدة';
      default:
        return recurrence;
    }
  }
}
