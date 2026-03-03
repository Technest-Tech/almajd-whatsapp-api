class StudentModel {
  final int id;
  final String name;
  final String? phone;
  final String status; // active, inactive, suspended
  final String? guardianName;
  final String? guardianPhone;
  final String? guardianRelation;
  final DateTime? enrollmentDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudentModel({
    required this.id,
    required this.name,
    this.phone,
    this.status = 'active',
    this.guardianName,
    this.guardianPhone,
    this.guardianRelation,
    this.enrollmentDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id'],
      name: json['name'] ?? '',
      phone: json['phone'],
      status: json['status'] ?? 'active',
      guardianName: json['guardian']?['name'] ?? json['guardian_name'],
      guardianPhone: json['guardian']?['phone'] ?? json['guardian_phone'],
      guardianRelation: json['guardian']?['relation'] ?? json['guardian_relation'],
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
      if (phone != null) 'phone': phone,
      'status': status,
      if (guardianName != null) 'guardian_name': guardianName,
      if (guardianPhone != null) 'guardian_phone': guardianPhone,
      if (guardianRelation != null) 'guardian_relation': guardianRelation,
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
