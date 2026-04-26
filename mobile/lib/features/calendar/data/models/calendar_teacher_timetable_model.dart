import 'package:equatable/equatable.dart';

class CalendarTeacherTimetableModel extends Equatable {
  final int id;
  final int teacherId;
  final String? teacherName;
  final String day;
  final String startTime;
  final String? finishTime;
  final String studentName;
  final String country;
  final String status;
  final int? studentId;
  final DateTime? reactiveDate;
  final DateTime? deletedDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CalendarTeacherTimetableModel({
    required this.id,
    required this.teacherId,
    this.teacherName,
    required this.day,
    required this.startTime,
    this.finishTime,
    required this.studentName,
    required this.country,
    required this.status,
    this.studentId,
    this.reactiveDate,
    this.deletedDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CalendarTeacherTimetableModel.fromJson(Map<String, dynamic> json) {
    return CalendarTeacherTimetableModel(
      id: json['id'] as int? ?? 0,
      teacherId: json['teacher_id'] as int? ?? 0,
      teacherName: json['teacher'] != null && json['teacher'] is Map
          ? (json['teacher'] as Map<String, dynamic>)['name'] as String?
          : null,
      day: json['day'] as String? ?? 'Sunday',
      startTime: json['start_time'] as String? ?? '00:00:00',
      finishTime: json['finish_time'] as String?,
      studentName: json['student_name'] as String? ?? '',
      country: json['country'] as String? ?? 'canada',
      status: json['status'] as String? ?? 'active',
      studentId: json['student_id'] as int?,
      reactiveDate: json['reactive_date'] != null
          ? DateTime.tryParse(json['reactive_date'] as String)
          : null,
      deletedDate: json['deleted_date'] != null
          ? DateTime.tryParse(json['deleted_date'] as String)
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
      'teacher_id': teacherId,
      'day': day,
      'start_time': startTime,
      'finish_time': finishTime,
      'student_name': studentName,
      'country': country,
      'status': status,
      if (studentId != null) 'student_id': studentId,
      'reactive_date': reactiveDate?.toIso8601String().split('T')[0],
      'deleted_date': deletedDate?.toIso8601String().split('T')[0],
    };
  }

  @override
  List<Object?> get props => [
        id,
        teacherId,
        day,
        startTime,
        finishTime,
        studentName,
        country,
        status,
        studentId,
      ];
}
