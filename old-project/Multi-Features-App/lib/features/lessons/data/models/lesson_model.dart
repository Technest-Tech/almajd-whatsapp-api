import 'package:equatable/equatable.dart';
import '../../../courses/data/models/course_model.dart';

class LessonModel extends Equatable {
  final int id;
  final int courseId;
  final CourseModel? course;
  final DateTime date;
  final int duration; // in minutes
  final String status; // present, cancelled
  final String? notes;
  final double? duty;
  final int createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LessonModel({
    required this.id,
    required this.courseId,
    this.course,
    required this.date,
    required this.duration,
    required this.status,
    this.notes,
    this.duty,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LessonModel.fromJson(Map<String, dynamic> json) {
    // Safely parse course
    CourseModel? course;
    if (json['course'] != null) {
      if (json['course'] is Map<String, dynamic>) {
        course = CourseModel.fromJson(json['course'] as Map<String, dynamic>);
      }
    }

    // Safely parse status (handle enum objects or strings)
    String status;
    if (json['status'] is String) {
      status = json['status'] as String;
    } else if (json['status'] is Map) {
      // Handle enum object format {value: "present"}
      final statusMap = json['status'] as Map;
      status = (statusMap['value'] ?? statusMap['name'] ?? 'present').toString();
    } else {
      status = json['status'].toString();
    }

    // Safely parse dates
    DateTime parseDate(dynamic dateValue) {
      if (dateValue is String) {
        return DateTime.parse(dateValue);
      } else if (dateValue is Map) {
        // Handle date object format
        final dateStr = dateValue['date'] ?? dateValue.toString();
        return DateTime.parse(dateStr.toString());
      } else {
        return DateTime.parse(dateValue.toString());
      }
    }

    // Safely parse created_by (can be int or user object)
    int _parseCreatedBy(dynamic createdByValue) {
      if (createdByValue is int) {
        return createdByValue;
      } else if (createdByValue is Map) {
        // Extract id from user object
        final id = createdByValue['id'];
        if (id is int) {
          return id;
        } else if (id != null) {
          return int.parse(id.toString());
        }
      } else if (createdByValue != null) {
        return int.parse(createdByValue.toString());
      }
      throw Exception('Invalid created_by value: $createdByValue');
    }

    return LessonModel(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      courseId: json['course_id'] is int 
          ? json['course_id'] as int 
          : int.parse(json['course_id'].toString()),
      course: course,
      date: parseDate(json['date']),
      duration: json['duration'] is int 
          ? json['duration'] as int 
          : int.parse(json['duration'].toString()),
      status: status,
      notes: json['notes']?.toString(),
      duty: json['duty'] != null
          ? (json['duty'] is double 
              ? json['duty'] as double 
              : double.tryParse(json['duty'].toString()))
          : null,
      createdBy: _parseCreatedBy(json['created_by']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'course_id': courseId,
      'date': date.toIso8601String().split('T')[0],
      'duration': duration,
      'status': status,
      'notes': notes,
      // duty is calculated automatically by backend, don't send it
    };
  }

  @override
  List<Object?> get props => [
        id,
        courseId,
        course,
        date,
        duration,
        status,
        notes,
        duty,
        createdBy,
      ];
}

