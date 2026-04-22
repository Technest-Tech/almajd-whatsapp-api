import 'dart:io';
import 'package:flutter/foundation.dart';

/// Application configuration constants
class AppConfig {
  AppConfig._();

  /// Backend base URL
  /// Production URL: https://multi.almajd.info
  /// 
  /// For local development:
  /// - Android Emulator: http://10.0.2.2:8000
  /// - Physical Device: Set BACKEND_URL environment variable or use your machine's IP
  ///   Example: http://192.168.1.100:8000 (replace with your actual IP)
  /// - iOS Simulator: http://127.0.0.1:8000
  /// 
  /// To find your IP address:
  /// - macOS/Linux: Run `ifconfig | grep "inet "` or `ip addr show`
  /// - Windows: Run `ipconfig` and look for IPv4 Address
  /// - Make sure your phone and computer are on the same WiFi network
  static String get backendBaseUrl {
    // Production URL
    return 'https://multi.almajd.info';
    
    // Uncomment below for local development
    // Check for environment variable first (useful for physical devices)
    // const backendUrl = String.fromEnvironment('BACKEND_URL', defaultValue: '');
    // if (backendUrl.isNotEmpty) {
    //   return backendUrl;
    // }
    // 
    // // Local development URLs
    // if (kIsWeb) {
    //   return 'http://127.0.0.1:8000';
    // }
    // 
    // if (Platform.isAndroid) {
    //   // For Android physical devices, use your machine's local IP address
    //   // For emulator, use 10.0.2.2
    //   // 
    //   // To use on physical device, replace with your actual IP:
    //   // You can find it by running: ifconfig | grep "inet " | grep -v 127.0.0.1
    //   // Make sure your phone and computer are on the same WiFi network
    //   
    //   // For physical device testing, uncomment and set your IP:
    //   return 'http://192.168.1.23:8000'; // Your machine's IP
    //   
    //   // For emulator, use this instead:
    //   // return 'http://10.0.2.2:8000';
    // } else if (Platform.isIOS) {
    //   return 'http://127.0.0.1:8000';
    // }
    // 
    // // Default for other platforms
    // return 'http://127.0.0.1:8000';
  }

  /// Certificate web interface URL
  static String get certificateUrl => '$backendBaseUrl/certificates';

  /// Certificate template selection URL
  static String get certificateIndexUrl => '$backendBaseUrl/certificates';

  /// Certificate editor URL (with template parameter)
  static String certificateEditorUrl({String template = 'default'}) {
    return '$backendBaseUrl/certificates/new?template=$template';
  }

  /// Timetable web interface URL
  static String get timetableUrl => '$backendBaseUrl/timetable';

  /// Teacher timetable view URL (view-only)
  static String teacherTimetableUrl(String teacherId) {
    return '$backendBaseUrl/timetable/teacher?teacher_id=$teacherId';
  }

  /// Admin API base URL for room management
  static const String adminApiBaseUrl = 'https://almajdmeet.org';
}

