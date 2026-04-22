import 'package:equatable/equatable.dart';

class CalendarStudentStopModel extends Equatable {
  final int id;
  final String studentName;
  final DateTime dateFrom;
  final DateTime dateTo;
  final String? reason;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CalendarStudentStopModel({
    required this.id,
    required this.studentName,
    required this.dateFrom,
    required this.dateTo,
    this.reason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CalendarStudentStopModel.fromJson(Map<String, dynamic> json) {
    return CalendarStudentStopModel(
      id: json['id'] as int? ?? 0,
      studentName: json['student_name'] as String? ?? '',
      dateFrom: json['date_from'] != null
          ? DateTime.tryParse(json['date_from'] as String) ?? DateTime.now()
          : DateTime.now(),
      dateTo: json['date_to'] != null
          ? DateTime.tryParse(json['date_to'] as String) ?? DateTime.now()
          : DateTime.now(),
      reason: json['reason'] as String?,
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
      'date_from': dateFrom.toIso8601String().split('T')[0],
      'date_to': dateTo.toIso8601String().split('T')[0],
      'reason': reason,
    };
  }

  CalendarStudentStopModel copyWith({
    int? id,
    String? studentName,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? reason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CalendarStudentStopModel(
      id: id ?? this.id,
      studentName: studentName ?? this.studentName,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, studentName, dateFrom, dateTo, reason];
}
