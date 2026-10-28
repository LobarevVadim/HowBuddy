import 'api_transport.dart';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/lesson_models.dart';
import '../models/app_models.dart';
import 'api_session.dart';
import 'ui_translations.dart';

class AuthApi {
  AuthApi({
    this.baseUrl = ApiSession.baseUrl,
  });

  final String baseUrl;

  Future<Map<String, dynamic>> startLesson({
    required String requestId,
    required String topicId,
    required String lessonId,
  }) async {
    return _readBody(
      await ApiSession.client.post(
        Uri.parse('$baseUrl/lessons/start'),
        headers: ApiSession.authenticatedHeaders,
        body: jsonEncode({'topicId': topicId, 'lessonId': lessonId, 'requestId': requestId}),
      ),
    );
  }

  Future<String?> fetchLastTopicId() async {
    final response = await ApiSession.client.get(
      Uri.parse('$baseUrl/account/last-topic'),
      headers: ApiSession.authenticatedHeaders,
    );
    final body = _readBody(response);
    return body['topicId']?.toString();
  }

  Future<void> saveLastTopicId(String topicId) async {
    final response = await ApiSession.client.put(
      Uri.parse('$baseUrl/account/last-topic'),
      headers: ApiSession.authenticatedHeaders,
      body: jsonEncode({'topicId': topicId}),
    );
    _readBody(response);
  }

  Future<int> saveAvatarPalette(int paletteIndex) async {
    final response = await ApiSession.client.put(
      Uri.parse('$baseUrl/account/avatar-palette'),
      headers: ApiSession.authenticatedHeaders,
      body: jsonEncode({'paletteIndex': paletteIndex}),
    );
    final body = _readBody(response);
    return int.tryParse(body['avatarPaletteIndex'].toString()) ?? 0;
  }

  Future<int> saveAvatarGlasses(int accessoryIndex) async {
    final response = await ApiSession.client.put(
      Uri.parse('$baseUrl/account/avatar-glasses'),
      headers: ApiSession.authenticatedHeaders,
      body: jsonEncode({'accessoryIndex': accessoryIndex}),
    );
    final body = _readBody(response);
    return int.tryParse(body['glassesAccessoryIndex'].toString()) ?? 0;
  }

  Future<String> saveAvatarEmoji(String emoji) async {
    final response = await ApiSession.client.put(
      Uri.parse('$baseUrl/account/avatar-emoji'),
      headers: ApiSession.authenticatedHeaders,
      body: jsonEncode({'emoji': emoji}),
    );
    final body = _readBody(response);
    return body['avatarEmoji']?.toString() ?? '';
  }

  Future<void> saveAccountPreferences({
    required String preferredLanguage,
    required int ageYears,
  }) async {
    final response = await ApiSession.client.put(
      Uri.parse('$baseUrl/account/preferences'),
      headers: ApiSession.authenticatedHeaders,
      body: jsonEncode({
        'preferredLanguage': preferredLanguage,
        'ageYears': ageYears,
      }),
    );
    _readBody(response);
  }

  Future<bool> hasCurrentLegalAcceptance() async {
    final response = await ApiSession.client.get(
      Uri.parse('$baseUrl/account/legal-acceptance'),
      headers: ApiSession.authenticatedHeaders,
    );
    final body = _readBody(response);
    return body['accepted'] == true;
  }

  Future<void> recordLegalAcceptance({
    required bool termsAccepted,
    required bool privacyAcknowledged,
    required bool cookiesAcknowledged,
    required bool refundsAcknowledged,
  }) async {
    final response = await ApiSession.client.put(
      Uri.parse('$baseUrl/account/legal-acceptance'),
      headers: ApiSession.authenticatedHeaders,
      body: jsonEncode({
        'termsAccepted': termsAccepted,
        'privacyAcknowledged': privacyAcknowledged,
        'cookiesAcknowledged': cookiesAcknowledged,
        'refundsAcknowledged': refundsAcknowledged,
      }),
    );
    _readBody(response);
  }

  Future<void> deleteOwnAccount() async {
    final response = await ApiSession.client.delete(
      Uri.parse('$baseUrl/account'),
      headers: ApiSession.authenticatedHeaders,
    );
    _readBody(response);
    ApiSession.clear();
  }

  Future<Account> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await ApiSession.client.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fullName': fullName,
        'email': email,
        'password': password,
      }),
    );

    return _readAccount(response);
  }

  Future<Account> login({
    required String identifier,
    required String password,
  }) async {
    final response = await ApiSession.client.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier, 'password': password}),
    );

    return _readAccount(response);
  }

  Future<GoogleAuthResult> googleSignIn({
    required String idToken,
    required bool allowRegistration,
  }) async {
    final response = await ApiSession.client.post(
      Uri.parse('$baseUrl/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'idToken': idToken,
        'allowRegistration': allowRegistration,
      }),
    );
    final body = _readBody(response);
    final sessionToken = body['sessionToken']?.toString();
    if (sessionToken == null || sessionToken.isEmpty) {
      throw AuthException('The server did not create a sign-in session.');
    }
    ApiSession.setToken(sessionToken);
    return GoogleAuthResult(
      account: Account.fromJson(body['account'] as Map<String, dynamic>),
      isNewUser: body['isNewUser'] == true,
    );
  }

  Future<TreeData> fetchTreeData({
    required String topicId,
    required String accountId,
  }) async {
    final response = await ApiSession.client.get(
      Uri.parse('$baseUrl/lessons/tree').replace(
        queryParameters: {
          'topic': topicId,
          'accountId': accountId,
          'language': UiTranslations.languageCode,
        },
      ),
      headers: ApiSession.authenticatedHeaders,
    );
    final Map<String, dynamic> body = _readBody(response);


    final levels = (body['levels'] as List<dynamic>)
        .map((level) => LessonLevel.fromJson(level as Map<String, dynamic>))
        .toList();
    final nextQuestions = (body['nextQuestions'] as List<dynamic>)
        .map(
          (question) =>
              LessonQuestion.fromJson(question as Map<String, dynamic>),
        )
        .toList();
    final topic = LessonTopic.fromJson(body['topic'] as Map<String, dynamic>);

    return TreeData(
      topic: topic,
      levels: levels,
      nextQuestions: nextQuestions,
      isSelectableTopic: body['isSelectableTopic'] == true,
    );
  }

  Future<LessonContent> fetchLessonExercises({
    required String topicId,
    required String lessonId,
  }) async {
    final response = await ApiSession.client.get(
      Uri.parse('$baseUrl/lessons/exercises').replace(
        queryParameters: {
          'topic': topicId,
          'lesson': lessonId,
          'language': UiTranslations.languageCode,
        },
      ),
    );
    final Map<String, dynamic> body = _readBody(response);


    final exercises = (body['exercises'] as List<dynamic>)
        .map(
          (exercise) =>
              LessonExercise.fromJson(exercise as Map<String, dynamic>),
        )
        .toList();
    return LessonContent(
      content: body['content']?.toString() ?? '',
      exercises: exercises,
    );
  }

  Future<LessonCompletion> completeLesson({
    required String completionId,
    required String accountId,
    required String topicId,
    required String lessonId,
    required int correctAnswers,
    required int exerciseCount,
    required int durationSeconds,
  }) async {
    final response = await ApiSession.client.post(
      Uri.parse('$baseUrl/lessons/complete'),
      headers: ApiSession.authenticatedHeaders,
      body: jsonEncode({
        'completionId': completionId,
        'accountId': accountId,
        'topicId': topicId,
        'lessonId': lessonId,
        'correctAnswers': correctAnswers,
        'exerciseCount': exerciseCount,
        'durationSeconds': durationSeconds,
      }),
    );
    final Map<String, dynamic> body = _readBody(response);


    return LessonCompletion.fromJson(body);
  }

  Future<XpWeeklySummary> fetchWeeklyXp(String accountId) async {
    final response = await ApiSession.client.get(
      Uri.parse(
        '$baseUrl/xp/weekly',
      ).replace(queryParameters: {'accountId': accountId}),
      headers: ApiSession.authenticatedHeaders,
    );
    final Map<String, dynamic> body = _readBody(response);


    return XpWeeklySummary.fromJson(body);
  }

  Future<List<LessonTopic>> fetchOnboardingTopics() async {
    final response = await ApiSession.client.get(
      Uri.parse(
        '$baseUrl/onboarding/topics',
      ).replace(queryParameters: {'language': UiTranslations.languageCode}),
    );
    final Map<String, dynamic> body = _readBody(response);


    final topics = body['topics'] as List<dynamic>;
    return topics
        .map((topic) => LessonTopic.fromJson(topic as Map<String, dynamic>))
        .toList();
  }

  Future<NotepadTreeNode> fetchNotepadTree(String accountId) async {
    final response = await ApiSession.client.get(
      Uri.parse('$baseUrl/notepad/tree').replace(
        queryParameters: {
          'accountId': accountId,
          'language': UiTranslations.languageCode,
        },
      ),
      headers: ApiSession.authenticatedHeaders,
    );
    final Map<String, dynamic> body = _readBody(response);


    return NotepadTreeNode.fromJson(body['tree'] as Map<String, dynamic>);
  }

  Account _readAccount(http.Response response) {
    final body = _readBody(response);

    final sessionToken = body['sessionToken']?.toString();
    if (sessionToken == null || sessionToken.isEmpty) {
      throw AuthException(
        body['message']?.toString() ??
            'This sign-in method is not configured yet.',
      );
    }
    ApiSession.setToken(sessionToken);
    return Account.fromJson(body['account'] as Map<String, dynamic>);
  }

  Map<String, dynamic> _readBody(http.Response response) {
    try {
      return decodeApiBody(response);
    } on ApiTransportException catch (error) {
      throw AuthException(error.message, code: error.code);
    }
  }
}

class GoogleAuthResult {
  const GoogleAuthResult({required this.account, required this.isNewUser});

  final Account account;
  final bool isNewUser;
}
