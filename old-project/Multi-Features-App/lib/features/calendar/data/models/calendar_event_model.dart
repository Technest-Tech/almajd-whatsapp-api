import 'package:equatable/equatable.dart';

class CalendarEventModel extends Equatable {
  final int id;
  final String title;
  final List<int> daysOfWeek;
  final String startTime;
  final String? endTime;
  final String? start; // For exceptional classes (one-time events)
  final Map<String, dynamic> extendedProps;

  const CalendarEventModel({
    required this.id,
    required this.title,
    required this.daysOfWeek,
    required this.startTime,
    this.endTime,
    this.start,
    required this.extendedProps,
  });

  factory CalendarEventModel.fromJson(Map<String, dynamic> json) {
    // Handle exceptional class IDs (format: "exceptional_123")
    int parsedId = 0;
    if (json['id'] is String && (json['id'] as String).startsWith('exceptional_')) {
      parsedId = int.tryParse((json['id'] as String).replaceFirst('exceptional_', '')) ?? 0;
    } else {
      parsedId = json['id'] as int? ?? 0;
    }

    return CalendarEventModel(
      id: parsedId,
      title: json['title'] as String? ?? '',
      daysOfWeek: json['daysOfWeek'] != null
          ? List<int>.from((json['daysOfWeek'] as List).map((e) => e as int? ?? 0))
          : [],
      startTime: json['startTime'] as String? ?? '00:00:00',
      endTime: json['endTime'] as String?,
      start: json['start'] as String?,
      extendedProps: json['extendedProps'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'daysOfWeek': daysOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'extendedProps': extendedProps,
    };
  }

  String get studentName {
    final value = extendedProps['studentName'];
    return value is String ? value : (value?.toString() ?? title);
  }
  
  String get country {
    final value = extendedProps['country'];
    return value is String ? value : (value?.toString() ?? 'canada');
  }
  
  int get teacherId {
    final value = extendedProps['teacherId'];
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
  
  String get teacherName {
    final value = extendedProps['teacherName'];
    return value is String ? value : (value?.toString() ?? '');
  }
  
  String get day {
    final value = extendedProps['day'];
    return value is String ? value : (value?.toString() ?? '');
  }
  
  String get type {
    final value = extendedProps['type'];
    return value is String ? value : (value?.toString() ?? 'recurring');
  }
  
  bool get isExceptional => type == 'exceptional';
  
  int? get exceptionalClassId {
    if (!isExceptional) return null;
    final value = extendedProps['exceptionalClassId'];
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
  
  String? get exceptionalDate {
    if (!isExceptional) return null;
    final value = extendedProps['date'];
    return value is String ? value : (value?.toString());
  }

  @override
  List<Object?> get props => [id, title, daysOfWeek, startTime, endTime, start, type];
}
