import 'api_transport.dart';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_models.dart';
import 'api_session.dart';

class GamificationApi {
  GamificationApi({
    this.baseUrl = ApiSession.baseUrl,
  });

  final String baseUrl;

  Future<GameState> fetchState(String accountId) async {
    final response = await ApiSession.client.get(
      _uri('/gamification', accountId),
      headers: ApiSession.authenticatedHeaders,
    );
    return _readState(response);
  }

  Future<GameState> saveStreakGoal(String accountId, int goalDays) async {
    final response = await ApiSession.client.post(
      Uri.parse('$baseUrl/gamification/streak-goal'),
      headers: ApiSession.authenticatedHeaders,
      body: jsonEncode({'goalDays': goalDays}),
    );
    return GameState.fromJson(_readBody(response));
  }

  Future<LessonHeartResult> consumeLessonHeart(String accountId) async {
    final response = await ApiSession.client.post(
      Uri.parse('$baseUrl/gamification/consume-heart'),
      headers: ApiSession.authenticatedHeaders,
      body: jsonEncode({'accountId': accountId}),
    );
    final body = _readBody(response);
    return LessonHeartResult(
      lessonAllowed: body['lessonAllowed'] == true,
      state: GameState.fromJson(body),
    );
  }

  Future<GameState> watchHeartVideo(String accountId) =>
      _postState('/gamification/heart-video', {'accountId': accountId});

  Future<GameState> watchEmeraldVideo(String accountId) =>
      _postState('/gamification/emerald-video', {'accountId': accountId});

  Future<GameState> purchaseXpBoost(
    String accountId, {
    required int durationMinutes,
  }) => _postState('/gamification/xp-boost', {
    'accountId': accountId,
    'durationMinutes': durationMinutes,
  });

  Future<GameState> _postState(String path, Map<String, Object> payload) async {
    final response = await ApiSession.client.post(
      Uri.parse('$baseUrl$path'),
      headers: ApiSession.authenticatedHeaders,
      body: jsonEncode(payload),
    );
    return GameState.fromJson(_readBody(response));
  }

  Future<GameState> _readState(http.Response response) =>
      Future.value(GameState.fromJson(_readBody(response)));

  Map<String, dynamic> _readBody(http.Response response) {
    try {
      return decodeApiBody(response);
    } on ApiTransportException catch (error) {
      throw AuthException(error.message);
    }
  }

  Uri _uri(String path, String accountId) => Uri.parse(
    '$baseUrl$path',
  ).replace(queryParameters: {'accountId': accountId});
}
