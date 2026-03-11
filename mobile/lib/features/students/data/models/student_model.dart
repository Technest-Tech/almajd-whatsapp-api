class StudentModel {
  final int id;
  final String name;
  final String? whatsappNumber;
  final String status; // active, inactive, suspended
  final String? country;
  final String? currency;
  final DateTime? enrollmentDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudentModel({
    required this.id,
    required this.name,
    this.whatsappNumber,
    this.status = 'active',
    this.country,
    this.currency,
    this.enrollmentDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id'],
      name: json['name'] ?? '',
      whatsappNumber: json['whatsapp_number'],
      status: json['status'] ?? 'active',
      country: json['country'],
      currency: json['currency'],
      enrollmentDate: json['enrollment_date'] != null
          ? DateTime.parse(json['enrollment_date'])
          : null,
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (whatsappNumber != null) 'whatsapp_number': whatsappNumber,
      'status': status,
      if (country != null) 'country': country,
      if (currency != null) 'currency': currency,
      if (notes != null) 'notes': notes,
    };
  }

  String get statusDisplay {
    switch (status) {
      case 'active':
        return 'نشط';
      case 'inactive':
        return 'غير نشط';
      case 'suspended':
        return 'موقوف';
      default:
        return status;
    }
  }

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}';
    }
    return name.isNotEmpty ? name[0] : '؟';
  }

  String get enrollmentDisplay {
    if (enrollmentDate == null) return 'غير محدد';
    final months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return '${enrollmentDate!.day} ${months[enrollmentDate!.month - 1]} ${enrollmentDate!.year}';
  }
}
