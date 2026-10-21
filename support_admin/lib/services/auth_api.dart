import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_session.dart';
import '../models/app_models.dart';

class AuthApi {
  final String baseUrl = ApiSession.baseUrl;

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier, 'password': password}),
    );
    _readSession(response);
  }

  Future<void> googleSignIn({
    required String idToken,
    required bool allowRegistration,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/google'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'idToken': idToken,
        'allowRegistration': allowRegistration,
      }),
    );
    _readSession(response);
  }

  void _readSession(http.Response response) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const AuthException(
        'The account server returned an invalid response.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(body['message']?.toString() ?? 'Sign in failed.');
    }
    final token = body['sessionToken']?.toString();
    if (token == null || token.isEmpty) {
      throw const AuthException('The server did not create a sign-in session.');
    }
    ApiSession.setToken(token);
  }
}
