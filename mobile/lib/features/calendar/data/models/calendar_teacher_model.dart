import 'package:equatable/equatable.dart';

class CalendarTeacherModel extends Equatable {
  final int id;
  final String name;
  final String whatsappNumber;
  final int? timetablesCount;
  final int? exceptionalClassesCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CalendarTeacherModel({
    required this.id,
    required this.name,
    required this.whatsappNumber,
    this.timetablesCount,
    this.exceptionalClassesCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CalendarTeacherModel.fromJson(Map<String, dynamic> json) {
    return CalendarTeacherModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      // Backend returns 'whatsapp' not 'whatsapp_number' for calendar_teachers
      whatsappNumber: (json['whatsapp'] ?? json['whatsapp_number']) as String? ?? '',
      timetablesCount: json['timetables_count'] as int?,
      exceptionalClassesCount: json['exceptional_classes_count'] as int?,
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
      'name': name,
      'whatsapp': whatsappNumber, // Backend expects 'whatsapp' not 'whatsapp_number'
    };
  }

  CalendarTeacherModel copyWith({
    int? id,
    String? name,
    String? whatsappNumber,
    int? timetablesCount,
    int? exceptionalClassesCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CalendarTeacherModel(
      id: id ?? this.id,
      name: name ?? this.name,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      timetablesCount: timetablesCount ?? this.timetablesCount,
      exceptionalClassesCount: exceptionalClassesCount ?? this.exceptionalClassesCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, name, whatsappNumber];
}
