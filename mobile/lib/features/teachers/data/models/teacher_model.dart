class TeacherModel {
  final int id;
  final String name;
  final String? phone;
  final String? email;
  final List<String> subjects;
  final String availability; // available, busy, offline
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TeacherModel({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.subjects = const [],
    this.availability = 'available',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TeacherModel.fromJson(Map<String, dynamic> json) {
    return TeacherModel(
      id: json['id'],
      name: json['name'] ?? '',
      phone: json['phone'],
      email: json['email'],
      subjects: json['subjects'] != null
          ? (json['subjects'] as List).map((s) => s.toString()).toList()
          : [],
      availability: json['availability'] ?? 'available',
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      'subjects': subjects,
      'availability': availability,
      if (notes != null) 'notes': notes,
    };
  }

  String get availabilityDisplay {
    switch (availability) {
      case 'available':
        return 'متاح';
      case 'busy':
        return 'مشغول';
      case 'offline':
        return 'غير متصل';
      default:
        return availability;
    }
  }

  String get subjectsDisplay {
    if (subjects.isEmpty) return 'لا توجد مواد';
    return subjects.join(' • ');
  }

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}';
    }
    return name.isNotEmpty ? name[0] : '؟';
  }
}
