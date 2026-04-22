import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_config.dart';
import '../models/client_credentials_model.dart';

class ClientCredentialsService {
  static const String _endpoint = '/client-credentials';
  static const String _defaultEmail = 'almajd@admin.com';
  static const String _defaultPassword = 'almajd123';

  /// Fetch client credentials from Laravel backend
  /// Returns default credentials if API fails
  static Future<ClientCredentials> getCredentials() async {
    try {
      final url = Uri.parse('${AppConfig.backendBaseUrl}/api$_endpoint');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return ClientCredentials.fromJson(data);
      } else {
        // Return default credentials on error
        return ClientCredentials(
          email: _defaultEmail,
          password: _defaultPassword,
        );
      }
    } catch (e) {
      // Return default credentials on any error
      return ClientCredentials(
        email: _defaultEmail,
        password: _defaultPassword,
      );
    }
  }
}
