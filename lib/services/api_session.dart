import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiSession {
  ApiSession._();

  static String? _token;
  static const _baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:3000',
  );

  static void setToken(String token) => _token = token;

  static void clear() => _token = null;

  static String get _localDate {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  static Map<String, String> get authenticatedHeaders => {
    'Content-Type': 'application/json',
    'X-Client-Date': _localDate,
    'X-Client-UTC-Offset-Minutes': '${DateTime.now().timeZoneOffset.inMinutes}',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Future<Map<String, dynamic>> getJson(String path) async {
    final response = await http.get(
      Uri.parse('$_baseUrl$path'),
      headers: authenticatedHeaders,
    );
    return _decode(response);
  }

  static Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: authenticatedHeaders,
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  static Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http.put(
      Uri.parse('$_baseUrl$path'),
      headers: authenticatedHeaders,
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  static Future<Map<String, dynamic>> deleteJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl$path'),
      headers: authenticatedHeaders,
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  static Map<String, dynamic> _decode(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiSessionException(
        body['message']?.toString() ?? 'Request failed.',
      );
    }
    return body;
  }
}

class ApiSessionException implements Exception {
  const ApiSessionException(this.message);
  final String message;
}
