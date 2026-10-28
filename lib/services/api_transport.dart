import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiTransportException implements Exception {
  const ApiTransportException(this.code, this.message, {this.statusCode});
  final String code;
  final String message;
  final int? statusCode;
}

Map<String, dynamic> decodeApiBody(http.Response response) {
  Object? body;
  try {
    body = jsonDecode(response.body);
  } on FormatException {
    throw ApiTransportException(
      'invalid_response',
      'The server could not respond. Please try again.',
      statusCode: response.statusCode,
    );
  }
  if (body is! Map<String, dynamic>) {
    throw ApiTransportException(
      'invalid_response',
      'The server could not respond. Please try again.',
      statusCode: response.statusCode,
    );
  }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw ApiTransportException(
      body['code']?.toString() ?? 'request_failed',
      body['message'] is String
          ? body['message'] as String
          : 'Request failed. Please try again.',
      statusCode: response.statusCode,
    );
  }
  return body;
}

/// One deadline covers headers AND body. Writes are never automatically retried.
/// Generation checks prevent old account responses from entering current state.
class ApiHttpClient extends http.BaseClient {
  ApiHttpClient({
    http.Client? inner,
    required this.sessionGeneration,
    this.onUnauthorized,
    this.timeout = const Duration(seconds: 35),
  }) : _inner = inner ?? http.Client();
  final http.Client _inner;
  final int Function() sessionGeneration;
  final void Function()? onUnauthorized;
  final Duration timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final generation = sessionGeneration();
    try {
      final response = await (() async {
        final result = await _inner.send(request);
        final bytes = await result.stream.toBytes();
        return http.StreamedResponse(
          Stream.value(bytes),
          result.statusCode,
          headers: result.headers,
          reasonPhrase: result.reasonPhrase,
          request: result.request,
          isRedirect: result.isRedirect,
          persistentConnection: result.persistentConnection,
          contentLength: bytes.length,
        );
      })().timeout(timeout);
      if (generation != sessionGeneration()) {
        throw const ApiTransportException(
          'session_changed',
          'Your session changed. Please try again.',
        );
      }
      if (response.statusCode == 401 && request.headers.keys.any((key) => key.toLowerCase() == 'authorization')) {
        onUnauthorized?.call();
      }
      return response;
    } on TimeoutException {
      throw const ApiTransportException(
        'timeout',
        'The request took too long. Please try again.',
      );
    } on http.ClientException {
      throw const ApiTransportException(
        'offline',
        'Could not connect. Check your connection and try again.',
      );
    }
  }

  @override
  void close() => _inner.close();
}
