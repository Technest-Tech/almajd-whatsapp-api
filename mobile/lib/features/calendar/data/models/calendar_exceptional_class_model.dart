import 'package:equatable/equatable.dart';

class CalendarExceptionalClassModel extends Equatable {
  final int id;
  final String studentName;
  final DateTime date;
  final String time;
  final int teacherId;
  final String? teacherName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CalendarExceptionalClassModel({
    required this.id,
    required this.studentName,
    required this.date,
    required this.time,
    required this.teacherId,
    this.teacherName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CalendarExceptionalClassModel.fromJson(Map<String, dynamic> json) {
    return CalendarExceptionalClassModel(
      id: json['id'] as int? ?? 0,
      studentName: json['student_name'] as String? ?? '',
      date: json['date'] != null
          ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      time: json['time'] as String? ?? '00:00:00',
      teacherId: json['teacher_id'] as int? ?? 0,
      teacherName: json['teacher'] != null && json['teacher'] is Map
          ? (json['teacher'] as Map<String, dynamic>)['name'] as String?
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'student_name': studentName,
      'date': date.toIso8601String().split('T')[0],
      'time': time,
      'teacher_id': teacherId,
    };
  }

  @override
  List<Object?> get props => [id, studentName, date, time, teacherId];
}
