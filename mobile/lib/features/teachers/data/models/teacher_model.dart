class TeacherModel {
  final int id;
  final String name;
  final String? whatsappNumber;
  final String? zoomLink;
  final List<String> subjects;
  final String availability; // available, busy, offline
  final DateTime createdAt;
  final DateTime updatedAt;

  const TeacherModel({
    required this.id,
    required this.name,
    this.whatsappNumber,
    this.zoomLink,
    this.subjects = const [],
    this.availability = 'available',
    required this.createdAt,
    required this.updatedAt,
  });

  factory TeacherModel.fromJson(Map<String, dynamic> json) {
    return TeacherModel(
      id: json['id'],
      name: json['name'] ?? '',
      whatsappNumber: json['whatsapp_number'],
      zoomLink: json['zoom_link'],
      subjects: json['subjects'] != null
          ? (json['subjects'] as List).map((s) => s.toString()).toList()
          : [],
      availability: json['availability'] ?? 'available',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (whatsappNumber != null) 'whatsapp_number': whatsappNumber,
      if (zoomLink != null) 'zoom_link': zoomLink,
      'subjects': subjects,
      'availability': availability,
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
