import 'package:equatable/equatable.dart';

class StudentModel extends Equatable {
  final int id;
  final String name;
  final String email;
  final String? whatsappNumber;
  final String? country;
  final String? currency;
  final double? hourPrice;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudentModel({
    required this.id,
    required this.name,
    required this.email,
    this.whatsappNumber,
    this.country,
    this.currency,
    this.hourPrice,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      whatsappNumber: json['whatsapp_number'] as String?,
      country: json['country'] as String?,
      currency: json['currency'] as String?,
      hourPrice: json['hour_price'] != null
          ? double.parse(json['hour_price'].toString())
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'whatsapp_number': whatsappNumber,
      'country': country,
      'currency': currency,
      'hour_price': hourPrice,
    };
  }

  StudentModel copyWith({
    int? id,
    String? name,
    String? email,
    String? whatsappNumber,
    String? country,
    String? currency,
    double? hourPrice,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      country: country ?? this.country,
      currency: currency ?? this.currency,
      hourPrice: hourPrice ?? this.hourPrice,
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
        country,
        currency,
        hourPrice,
      ];
}

