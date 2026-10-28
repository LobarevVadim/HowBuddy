import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'api_transport.dart';

class ApiSession {
  ApiSession._();

  static String? _token;
  static int _generation = 0;
  static int get generation => _generation;
  static final http.Client client = ApiHttpClient(
    sessionGeneration: () => _generation,
    onUnauthorized: clear,
  );
  static String _clientTimeZone = 'UTC';
  static const baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:3000',
  );

  static void setToken(String token) {
    _generation++;
    _token = token;
  }

  static Future<void> loadClientTimeZone() async {
    try {
      _clientTimeZone = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      // Keep UTC as a safe fallback if the platform cannot report its zone.
    }
  }

  static void clear() {
    _generation++;
    _token = null;
  }

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
    'X-Client-Time-Zone': _clientTimeZone,
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Future<Map<String, dynamic>> getJson(String path) async {
    final response = await ApiSession.client.get(
      Uri.parse('$baseUrl$path'),
      headers: authenticatedHeaders,
    );
    return _decode(response);
  }

  static Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await ApiSession.client.post(
      Uri.parse('$baseUrl$path'),
      headers: authenticatedHeaders,
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  static Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await ApiSession.client.put(
      Uri.parse('$baseUrl$path'),
      headers: authenticatedHeaders,
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  static Future<Map<String, dynamic>> deleteJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await ApiSession.client.delete(
      Uri.parse('$baseUrl$path'),
      headers: authenticatedHeaders,
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  static Map<String, dynamic> _decode(http.Response response) {
    try {
      return decodeApiBody(response);
    } on ApiTransportException catch (error) {
      throw ApiSessionException(error.message);
    }
  }
}

class ApiSessionException implements Exception {
  const ApiSessionException(this.message);
  final String message;
}
