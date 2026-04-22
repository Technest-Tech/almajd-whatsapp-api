import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../../../core/constants/app_config.dart';
import 'client_credentials_service.dart';

class ClientAuthService {
  static const String _loginEndpoint = '/api/auth/login';
  static Dio? _dio;
  static CookieJar? _cookieJar;
  static String? _sessionToken;
  static Map<String, dynamic>? _currentUser;

  /// Initialize Dio with cookie support
  static Future<void> _initDio() async {
    if (_dio != null) return;

    try {
      // Initialize cookie jar
      final directory = await getApplicationDocumentsDirectory();
      final cookiePath = path.join(directory.path, 'client_cookies');
      _cookieJar = PersistCookieJar(
        storage: FileStorage(cookiePath),
      );

      // Create Dio instance
      _dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.adminApiBaseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      // Add cookie manager
      _dio!.interceptors.add(CookieManager(_cookieJar!));
    } catch (e) {
      // Fallback to in-memory cookie jar
      _cookieJar = CookieJar();
      _dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.adminApiBaseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      _dio!.interceptors.add(CookieManager(_cookieJar!));
    }
  }

  /// Auto-login with credentials from backend
  static Future<Map<String, dynamic>> autoLogin() async {
    try {
      // Initialize Dio
      await _initDio();

      // Get credentials from Laravel backend
      final credentials = await ClientCredentialsService.getCredentials();

      // Prepare login request
      final response = await _dio!.post(
        _loginEndpoint,
        data: {
          'email': credentials.email,
          'password': credentials.password,
          'role': 'CLIENT',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;

        // Store session info
        if (data.containsKey('user')) {
          _currentUser = data['user'] as Map<String, dynamic>;
          _sessionToken = _currentUser!['clientId'] as String?;
        }

        return {
          'success': true,
          'user': _currentUser,
        };
      } else {
        throw Exception('فشل تسجيل الدخول');
      }
    } catch (e) {
      if (e is DioException) {
        final errorData = e.response?.data as Map<String, dynamic>?;
        throw Exception(errorData?['error'] ?? 'فشل تسجيل الدخول');
      }
      throw Exception('خطأ في تسجيل الدخول: ${e.toString()}');
    }
  }

  /// Get current user
  static Map<String, dynamic>? get currentUser => _currentUser;

  /// Get Dio instance for API calls (with cookies)
  static Future<Dio> getDio() async {
    await _initDio();
    return _dio!;
  }

  /// Logout - clear cookies and session
  static Future<void> logout() async {
    _sessionToken = null;
    _currentUser = null;
    if (_cookieJar != null) {
      try {
        await _cookieJar!.deleteAll();
      } catch (e) {
        // Ignore errors
      }
    }
  }

  /// Check if user is logged in
  static bool get isLoggedIn => _sessionToken != null && _currentUser != null;
}
