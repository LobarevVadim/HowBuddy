import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_session.dart';

class BoboChatTurn {
  const BoboChatTurn({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
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

  Future<String> sendMessage({
    required String topicId,
    required String lessonId,
    required int? exerciseIndex,
    required String studentAnswer,
    required bool answerSubmitted,
    required bool? answerCorrect,
    required String message,
    required List<BoboChatTurn> history,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bobo/chat'),
      headers: ApiSession.authenticatedHeaders,
      body: jsonEncode({
        'topicId': topicId,
        'lessonId': lessonId,
        'exerciseIndex': exerciseIndex,
        'studentAnswer': studentAnswer,
        'answerSubmitted': answerSubmitted,
        'answerCorrect': answerCorrect,
        'message': message,
        'history': history.map((turn) => turn.toJson()).toList(),
      }),
    );

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const BoboApiException('unavailable');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BoboApiException(body['code']?.toString() ?? 'unavailable');
    }
    final reply = body['reply']?.toString().trim() ?? '';
    if (reply.isEmpty) throw const BoboApiException('unavailable');
    return reply;
  }
}
