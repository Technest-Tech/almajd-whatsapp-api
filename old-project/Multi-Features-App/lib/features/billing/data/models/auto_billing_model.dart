import 'package:equatable/equatable.dart';
import '../../../students/data/models/student_model.dart';

class AutoBillingModel extends Equatable {
  final int id;
  final int studentId;
  final StudentModel? student;
  final int year;
  final int month;
  final double totalHours;
  final double totalAmount;
  final String currency;
  final bool isPaid;
  final DateTime? paidAt;
  final String? paymentMethod;
  final String? paymentToken;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AutoBillingModel({
    required this.id,
    required this.studentId,
    this.student,
    required this.year,
    required this.month,
    required this.totalHours,
    required this.totalAmount,
    required this.currency,
    required this.isPaid,
    this.paidAt,
    this.paymentMethod,
    this.paymentToken,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AutoBillingModel.fromJson(Map<String, dynamic> json) {
    return AutoBillingModel(
      id: json['id'] as int,
      studentId: json['student_id'] as int,
      student: json['student'] != null
          ? StudentModel.fromJson(json['student'] as Map<String, dynamic>)
          : null,
      year: json['year'] as int,
      month: json['month'] as int,
      totalHours: double.parse(json['total_hours'].toString()),
      totalAmount: double.parse(json['total_amount'].toString()),
      currency: json['currency'] as String,
      isPaid: json['is_paid'] as bool? ?? false,
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
      paymentMethod: json['payment_method'] as String?,
      paymentToken: json['payment_token'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'year': year,
      'month': month,
      'total_hours': totalHours,
      'total_amount': totalAmount,
      'currency': currency,
      'is_paid': isPaid,
      'paid_at': paidAt?.toIso8601String(),
      'payment_method': paymentMethod,
      'payment_token': paymentToken,
    };
  }

  AutoBillingModel copyWith({
    int? id,
    int? studentId,
    StudentModel? student,
    int? year,
    int? month,
    double? totalHours,
    double? totalAmount,
    String? currency,
    bool? isPaid,
    DateTime? paidAt,
    String? paymentMethod,
    String? paymentToken,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AutoBillingModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      student: student ?? this.student,
      year: year ?? this.year,
      month: month ?? this.month,
      totalHours: totalHours ?? this.totalHours,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      isPaid: isPaid ?? this.isPaid,
      paidAt: paidAt ?? this.paidAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentToken: paymentToken ?? this.paymentToken,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get monthName {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }

  @override
  List<Object?> get props => [
        id,
        studentId,
        student,
        year,
        month,
        totalHours,
        totalAmount,
        currency,
        isPaid,
        paidAt,
        paymentMethod,
        paymentToken,
      ];
}
