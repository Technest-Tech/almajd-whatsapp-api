import 'package:equatable/equatable.dart';
import '../../../students/data/models/student_model.dart';
import '../../../teachers/data/models/teacher_model.dart';

class CourseModel extends Equatable {
  final int id;
  final String name;
  final int studentId;
  final int teacherId;
  final StudentModel? student;
  final TeacherModel? teacher;
  final int lessonsCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CourseModel({
    required this.id,
    required this.name,
    required this.studentId,
    required this.teacherId,
    this.student,
    this.teacher,
    this.lessonsCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      id: json['id'] as int,
      name: json['name'] as String,
      studentId: json['student_id'] as int,
      teacherId: json['teacher_id'] as int,
      student: json['student'] != null
          ? StudentModel.fromJson(json['student'] as Map<String, dynamic>)
          : null,
      teacher: json['teacher'] != null
          ? TeacherModel.fromJson(json['teacher'] as Map<String, dynamic>)
          : null,
      lessonsCount: json['lessons_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'student_id': studentId,
      'teacher_id': teacherId,
    };
  }

  @override
  List<Object?> get props => [
        id,
        name,
        studentId,
        teacherId,
        student,
        teacher,
        lessonsCount,
      ];
}

