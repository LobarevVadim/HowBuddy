import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_session.dart';

class BoboChatTurn {
  const BoboChatTurn({required this.role, required this.content});

  final String role;
  final String content;
}

class BoboConversation {
  const BoboConversation({required this.id, required this.messages});

  final String id;
  final List<BoboChatTurn> messages;

  factory BoboConversation.fromJson(Map<String, dynamic> json) {
    final conversation = json['conversation'] as Map<String, dynamic>? ?? {};
    final messages = json['messages'] as List<dynamic>? ?? const [];
    return BoboConversation(
      id: conversation['id']?.toString() ?? '',
      messages: messages.map((item) {
        final message = item as Map<String, dynamic>;
        return BoboChatTurn(
          role: message['role'].toString(),
          content: message['content'].toString(),
        );
      }).toList(),
    );
  }
}

class BoboApiException implements Exception {
  const BoboApiException(this.code);

  final String code;
}

class BoboTutorApi {
  BoboTutorApi({
    this.baseUrl = const String.fromEnvironment(
      'API_URL',
      defaultValue: 'http://localhost:3000',
    ),
  });

  final String baseUrl;

  Future<BoboConversation> openConversation({
    required String topicId,
    required String lessonId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bobo/conversations'),
      headers: ApiSession.authenticatedHeaders,
      body: jsonEncode({'topicId': topicId, 'lessonId': lessonId}),
    );
    return BoboConversation.fromJson(_decode(response));
  }

  Future<String> sendMessage({
    required String conversationId,
    required String topicId,
    required String lessonId,
    required int? exerciseIndex,
    required String studentAnswer,
    required String message,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bobo/conversations/$conversationId/messages'),
      headers: ApiSession.authenticatedHeaders,
      body: jsonEncode({
        'topicId': topicId,
        'lessonId': lessonId,
        'exerciseIndex': exerciseIndex,
        'studentAnswer': studentAnswer,
        'message': message,
      }),
    );
    final body = _decode(response);
    final reply = body['reply']?.toString().trim() ?? '';
    if (reply.isEmpty) throw const BoboApiException('unavailable');
    return reply;
  }

  Future<void> clearConversation(String conversationId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/bobo/conversations/$conversationId'),
      headers: ApiSession.authenticatedHeaders,
    );
    _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const BoboApiException('unavailable');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BoboApiException(body['code']?.toString() ?? 'unavailable');
    }
    return body;
  }
}
