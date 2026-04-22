/// User role enumeration for role-based access control
enum UserRole {
  admin,
  teacher,
  student,
  calendarViewer,
  certificateViewer;

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.student:
        return 'Student';
      case UserRole.calendarViewer:
        return 'Calendar Viewer';
      case UserRole.certificateViewer:
        return 'Certificate Viewer';
    }
  }

  /// Check if role has access to a specific feature
  bool hasAccess(String feature) {
    switch (this) {
      case UserRole.admin:
        return true; // Admin has access to everything
      case UserRole.teacher:
        return _teacherAccess.contains(feature);
      case UserRole.student:
        return _studentAccess.contains(feature);
      case UserRole.calendarViewer:
        return _calendarViewerAccess.contains(feature);
      case UserRole.certificateViewer:
        return _certificateViewerAccess.contains(feature);
    }
  }

  static const List<String> _teacherAccess = [
    'meetings',
    'courses',
    'calendar',
  ];

  static const List<String> _studentAccess = [
    'courses',
    'calendar',
  ];

  static const List<String> _calendarViewerAccess = [
    'calendar',
  ];

  static const List<String> _certificateViewerAccess = [
    'certificates',
  ];
}


