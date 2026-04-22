import 'package:equatable/equatable.dart';
import '../../../students/data/models/student_model.dart';

class ManualBillingModel extends Equatable {
  final int id;
  final List<int> studentIds;
  final List<StudentModel>? students;
  final double amount;
  final String currency;
  final String? message;
  final String? paymentToken;
  final bool isPaid;
  final DateTime? paidAt;
  final String? paymentMethod;
  final int createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ManualBillingModel({
    required this.id,
    required this.studentIds,
    this.students,
    required this.amount,
    required this.currency,
    this.message,
    this.paymentToken,
    required this.isPaid,
    this.paidAt,
    this.paymentMethod,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ManualBillingModel.fromJson(Map<String, dynamic> json) {
    return ManualBillingModel(
      id: json['id'] as int,
      studentIds: (json['student_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      students: json['students'] != null
          ? (json['students'] as List<dynamic>)
              .map((e) => StudentModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      amount: double.parse(json['amount'].toString()),
      currency: json['currency'] as String,
      message: json['message'] as String?,
      paymentToken: json['payment_token'] as String?,
      isPaid: json['is_paid'] as bool? ?? false,
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
      paymentMethod: json['payment_method'] as String?,
      createdBy: json['created_by'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'student_ids': studentIds,
      'amount': amount,
      'currency': currency,
      'message': message,
    };
  }

  ManualBillingModel copyWith({
    int? id,
    List<int>? studentIds,
    List<StudentModel>? students,
    double? amount,
    String? currency,
    String? message,
    String? paymentToken,
    bool? isPaid,
    DateTime? paidAt,
    String? paymentMethod,
    int? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ManualBillingModel(
      id: id ?? this.id,
      studentIds: studentIds ?? this.studentIds,
      students: students ?? this.students,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      message: message ?? this.message,
      paymentToken: paymentToken ?? this.paymentToken,
      isPaid: isPaid ?? this.isPaid,
      paidAt: paidAt ?? this.paidAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get studentNames {
    if (students == null || students!.isEmpty) {
      return '${studentIds.length} student(s)';
    }
    return students!.map((s) => s.name).join(', ');
  }

  @override
  List<Object?> get props => [
        id,
        studentIds,
        students,
        amount,
        currency,
        message,
        paymentToken,
        isPaid,
        paidAt,
        paymentMethod,
        createdBy,
      ];
}
