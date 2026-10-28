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
  BoboTutorApi({this.baseUrl = ApiSession.baseUrl});

  final String baseUrl;

  Future<BoboConversation> openConversation({
    required String topicId,
    required String lessonId,
  }) async {
    final response = await ApiSession.client.post(
      Uri.parse('$baseUrl/bobo/conversations'),
      headers: ApiSession.authenticatedHeaders,
      body: jsonEncode({'topicId': topicId, 'lessonId': lessonId}),
    );
    return BoboConversation.fromJson(_decode(response));
  }

  Future<Map<int, bool?>> getAttemptedExercises({
    required String topicId,
    required String lessonId,
  }) async {
    final response = await ApiSession.client.get(
      Uri.parse(
        '$baseUrl/bobo/attempts',
      ).replace(queryParameters: {'topicId': topicId, 'lessonId': lessonId}),
      headers: ApiSession.authenticatedHeaders,
    );
    final body = _decode(response);
    final exercises = body['attemptedExercises'] as List<dynamic>? ?? const [];
    final result = <int, bool?>{};
    for (final item in exercises) {
      if (item is! Map<String, dynamic>) continue;
      final index = int.tryParse(item['exerciseIndex']?.toString() ?? '');
      if (index != null) result[index] = item['correct'] as bool?;
    }
    return result;
  }

  Future<bool> recordAttempt({
    Object? response,
    required String sessionId,
    required String topicId,
    required String lessonId,
    required int exerciseIndex,
    required String studentAnswer,
  }) async {
    final result = await ApiSession.client.post(
      Uri.parse('$baseUrl/bobo/attempts'),
      headers: ApiSession.authenticatedHeaders,
      body: jsonEncode({
        'sessionId': sessionId,
        'topicId': topicId,
        'lessonId': lessonId,
        'exerciseIndex': exerciseIndex,
        'studentAnswer': studentAnswer,
        'response': ?response,
      }),
    );
    final body = _decode(result);
    if (body['correct'] is! bool) {
      throw const BoboApiException('invalid_grade');
    }
    return body['correct'] as bool;
  }

  Future<String> sendMessage({
    required String conversationId,
    required String topicId,
    required String lessonId,
    required int? exerciseIndex,
    String? teachingAction,
    required String message,
  }) async {
    final response = await ApiSession.client.post(
      Uri.parse('$baseUrl/bobo/conversations/$conversationId/messages'),
      headers: ApiSession.authenticatedHeaders,
      body: jsonEncode({
        'topicId': topicId,
        'lessonId': lessonId,
        'exerciseIndex': exerciseIndex,
        'teachingAction': ?teachingAction,
        'message': message,
      }),
    );
    final body = _decode(response);
    final reply = body['reply']?.toString().trim() ?? '';
    if (reply.isEmpty) throw const BoboApiException('unavailable');
    return reply;
  }

  Future<void> clearConversation(String conversationId) async {
    final response = await ApiSession.client.delete(
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
