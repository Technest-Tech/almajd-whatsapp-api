class UserModel {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String availability;
  final int maxOpenTickets;
  final List<String> roles;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.availability = 'available',
    this.maxOpenTickets = 10,
    this.roles = const [],
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      avatarUrl: json['avatar_url'],
      availability: json['availability'] ?? 'available',
      maxOpenTickets: json['max_open_tickets'] ?? 10,
      roles: json['roles'] != null
          ? (json['roles'] as List).map((r) => r is String ? r : r['name'].toString()).toList()
          : [],
    );
  }

  String get primaryRole {
    if (roles.contains('admin')) return 'admin';
    if (roles.contains('senior_supervisor')) return 'senior_supervisor';
    if (roles.contains('supervisor')) return 'supervisor';
    return roles.isNotEmpty ? roles.first : 'unknown';
  }

  String get roleDisplayName {
    switch (primaryRole) {
      case 'admin':
        return 'مسؤول النظام';
      case 'senior_supervisor':
        return 'مشرف أول';
      case 'supervisor':
        return 'مشرف';
      default:
        return primaryRole;
    }
  }

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}';
    }
    return name.isNotEmpty ? name[0] : '?';
  }
}
