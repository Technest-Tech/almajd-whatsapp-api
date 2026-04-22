import 'package:equatable/equatable.dart';
import '../../../students/data/models/student_model.dart';

class TeacherModel extends Equatable {
  final int id;
  final String name;
  final String email;
  final String? whatsappNumber;
  final double? hourPrice;
  final String? currency;
  final String? bankName;
  final String? accountNumber;
  final List<StudentModel> assignedStudents;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TeacherModel({
    required this.id,
    required this.name,
    required this.email,
    this.whatsappNumber,
    this.hourPrice,
    this.currency,
    this.bankName,
    this.accountNumber,
    this.assignedStudents = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory TeacherModel.fromJson(Map<String, dynamic> json) {
    return TeacherModel(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      whatsappNumber: json['whatsapp_number'] as String?,
      hourPrice: json['hour_price'] != null
          ? double.parse(json['hour_price'].toString())
          : null,
      currency: json['currency'] as String?,
      bankName: json['bank_name'] as String?,
      accountNumber: json['account_number'] as String?,
      assignedStudents: json['assigned_students'] != null
          ? (json['assigned_students'] as List)
              .map((s) => StudentModel.fromJson(s))
              .toList()
          : [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'password': 'password', // Will be set separately
      'whatsapp_number': whatsappNumber,
      'hour_price': hourPrice,
      'currency': currency,
      'bank_name': bankName,
      'account_number': accountNumber,
      'student_ids': assignedStudents.map((s) => s.id).toList(),
    };
  }

  TeacherModel copyWith({
    int? id,
    String? name,
    String? email,
    String? whatsappNumber,
    double? hourPrice,
    String? currency,
    String? bankName,
    String? accountNumber,
    List<StudentModel>? assignedStudents,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TeacherModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      hourPrice: hourPrice ?? this.hourPrice,
      currency: currency ?? this.currency,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      assignedStudents: assignedStudents ?? this.assignedStudents,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        email,
        whatsappNumber,
        hourPrice,
        currency,
        bankName,
        accountNumber,
        assignedStudents,
      ];
}

