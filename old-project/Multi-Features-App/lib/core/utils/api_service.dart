import 'package:dio/dio.dart';
import '../constants/app_config.dart';

/// API Service for backend integration using Dio
class ApiService {
  late final Dio _dio;
  static String get baseUrl => '${AppConfig.backendBaseUrl}/api';

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptors for logging, auth tokens, etc.
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ),
    );

    // Add token interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Token will be added by setAuthToken method
          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            // For public routes (like calendar), don't clear token on 401
            // Only clear if it's actually an auth issue
            final path = error.requestOptions.path;
            final isPublicRoute = path.contains('/calendar/') || 
                                 path.contains('/calendar-teachers') ||
                                 path.contains('/calendar-student-stops') ||
                                 path.contains('/certificates');
            
            if (!isPublicRoute) {
              // Handle unauthorized - clear token and redirect to login
              clearAuthToken();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  // GET request
  Future<Response> get(String endpoint, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(endpoint, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // POST request
  Future<Response> post(String endpoint, {dynamic data}) async {
    try {
      return await _dio.post(endpoint, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // PUT request
  Future<Response> put(String endpoint, {dynamic data}) async {
    try {
      return await _dio.put(endpoint, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // DELETE request
  Future<Response> delete(String endpoint) async {
    try {
      return await _dio.delete(endpoint);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Error handler
  Exception _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return Exception('Connection timeout');
      case DioExceptionType.badResponse:
        // Try to extract error message from response
        final responseData = error.response?.data;
        if (responseData is Map<String, dynamic>) {
          // Check for error field (most common)
          if (responseData.containsKey('error')) {
            final errorMsg = responseData['error'];
            if (errorMsg is String) {
              return Exception(errorMsg);
            }
          }
          // Check for message field
          if (responseData.containsKey('message')) {
            final message = responseData['message'];
            if (message is String) {
              return Exception(message);
            }
          }
          // Check for errors field (validation errors)
          if (responseData.containsKey('errors')) {
            final errors = responseData['errors'];
            if (errors is Map<String, dynamic>) {
              // Get first error message
              final firstError = errors.values.first;
              if (firstError is List && firstError.isNotEmpty) {
                return Exception(firstError.first.toString());
              }
            }
          }
        }
        return Exception('Server error: ${error.response?.statusCode}');
      case DioExceptionType.cancel:
        return Exception('Request cancelled');
      default:
        return Exception('Network error occurred');
    }
  }

  // Set authorization token
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // Clear authorization token
  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  // Get dio instance for advanced operations like download
  Dio get dio => _dio;
}


