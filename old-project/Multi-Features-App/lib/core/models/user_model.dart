import 'package:equatable/equatable.dart';
import 'user_role.dart';

/// User model representing authenticated user
class UserModel extends Equatable {
  final String id;
  final String email;
  final String name;
  final UserRole role;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
  });

  @override
  List<Object?> get props => [id, email, name, role];

  /// Create user from JSON (for API integration)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Backend uses user_type, but we map it to role
    // Handle enum object format {value: "admin"} or string "admin"
    String userType = 'student';
    
    if (json['user_type'] != null) {
      final userTypeValue = json['user_type'];
      if (userTypeValue is String) {
        userType = userTypeValue;
      } else if (userTypeValue is Map) {
        // Handle enum object format {value: "admin"}
        userType = (userTypeValue['value'] ?? userTypeValue['name'] ?? 'student').toString();
      } else {
        userType = userTypeValue.toString().toLowerCase();
      }
    } else if (json['role'] != null) {
      final roleValue = json['role'];
      if (roleValue is String) {
        userType = roleValue;
      } else if (roleValue is Map) {
        userType = (roleValue['value'] ?? roleValue['name'] ?? 'student').toString();
      } else {
        userType = roleValue.toString().toLowerCase();
      }
    }
    
    // Normalize user type to match UserRole enum
    userType = userType.toLowerCase();
    if (userType == 'tutor') {
      userType = 'teacher';
    }
    // Map backend user_type to Flutter UserRole enum
    if (userType == 'calendar_viewer') {
      userType = 'calendarviewer';
    } else if (userType == 'certificate_viewer') {
      userType = 'certificateviewer';
    }
    
    return UserModel(
      id: json['id'].toString(),
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name.toLowerCase() == userType,
        orElse: () => UserRole.student,
      ),
    );
  }

  /// Convert user to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role.name,
    };
  }

  /// Mock user for testing - Admin
  static const UserModel mockAdmin = UserModel(
    id: '1',
    email: 'admin@almajd.com',
    name: 'Admin User',
    role: UserRole.admin,
  );

  /// Mock user for testing - Teacher
  static const UserModel mockTeacher = UserModel(
    id: '2',
    email: 'teacher@almajd.com',
    name: 'Teacher User',
    role: UserRole.teacher,
  );

  /// Mock user for testing - Student
  static const UserModel mockStudent = UserModel(
    id: '3',
    email: 'student@almajd.com',
    name: 'Student User',
    role: UserRole.student,
  );
}


