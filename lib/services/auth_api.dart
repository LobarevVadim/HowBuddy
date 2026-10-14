import 'dart:convert';

import 'package:http/http.dart' as http;

import '../features/learning/lesson_exercises.dart';
import '../models/app_models.dart';
import 'api_session.dart';

class AuthApi {
  AuthApi({
    this.baseUrl = const String.fromEnvironment(
      'API_URL',
      defaultValue: 'http://localhost:3000',
    ),
  });

  final String baseUrl;

  Future<String?> fetchLastTopicId() async {
    final response = await http.get(
      Uri.parse('$baseUrl/account/last-topic'),
      headers: ApiSession.authenticatedHeaders,
    );
    final body = _readBody(response);
    return body['topicId']?.toString();
  }

  Future<void> saveLastTopicId(String topicId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/account/last-topic'),
      headers: ApiSession.authenticatedHeaders,
      body: jsonEncode({'topicId': topicId}),
    );
    _readBody(response);
  }

  Future<int> saveAvatarPalette(int paletteIndex) async {
    final response = await http.put(
      Uri.parse('$baseUrl/account/avatar-palette'),
      headers: ApiSession.authenticatedHeaders,
      body: jsonEncode({'paletteIndex': paletteIndex}),
    );
    final body = _readBody(response);
    return int.tryParse(body['avatarPaletteIndex'].toString()) ?? 0;
  }

  Future<void> saveAccountPreferences({
    required String preferredLanguage,
    required int ageYears,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/account/preferences'),
      headers: ApiSession.authenticatedHeaders,
      body: jsonEncode({
        'preferredLanguage': preferredLanguage,
        'ageYears': ageYears,
      }),
    );
    _readBody(response);
  }

  Future<Account> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
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
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier, 'password': password}),
    );

    return _readAccount(response);
  }

  Future<Account> socialSignUp({
    required String provider,
    required String displayName,
    required String email,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/social-signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'provider': provider,
        'displayName': displayName,
        'email': email,
      }),
    );

    return _readAccount(response);
  }

  Future<GoogleAuthResult> googleSignIn({
    required String idToken,
    required bool allowRegistration,
  }) async {
    final response = await http.post(
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

  Future<List<LessonLevel>> fetchLessonLevels() async {
    final response = await http.get(
      Uri.parse('$baseUrl/lessons/tree'),
      headers: ApiSession.authenticatedHeaders,
    );
    final Map<String, dynamic> body = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        body['message']?.toString() ?? 'Could not load lessons.',
      );
    }

    final levels = body['levels'] as List<dynamic>;
    return levels
        .map((level) => LessonLevel.fromJson(level as Map<String, dynamic>))
        .toList();
  }

  Future<TreeData> fetchTreeData({
    required String topicId,
    required String accountId,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/lessons/tree',
      ).replace(queryParameters: {'topic': topicId, 'accountId': accountId}),
      headers: ApiSession.authenticatedHeaders,
    );
    final Map<String, dynamic> body = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        body['message']?.toString() ?? 'Could not load lessons.',
      );
    }

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

    return TreeData(topic: topic, levels: levels, nextQuestions: nextQuestions);
  }

  Future<LessonContent> fetchLessonExercises({
    required String topicId,
    required String lessonId,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/lessons/exercises',
      ).replace(queryParameters: {'topic': topicId, 'lesson': lessonId}),
    );
    final Map<String, dynamic> body = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        body['message']?.toString() ?? 'Could not load lesson exercises.',
      );
    }

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
    required String accountId,
    required String topicId,
    required String lessonId,
    required int correctAnswers,
    required int exerciseCount,
    required int durationSeconds,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/lessons/complete'),
      headers: ApiSession.authenticatedHeaders,
      body: jsonEncode({
        'accountId': accountId,
        'topicId': topicId,
        'lessonId': lessonId,
        'correctAnswers': correctAnswers,
        'exerciseCount': exerciseCount,
        'durationSeconds': durationSeconds,
      }),
    );
    final Map<String, dynamic> body = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        body['message']?.toString() ?? 'Could not complete lesson.',
      );
    }

    return LessonCompletion.fromJson(body);
  }

  Future<XpWeeklySummary> fetchWeeklyXp(String accountId) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/xp/weekly',
      ).replace(queryParameters: {'accountId': accountId}),
      headers: ApiSession.authenticatedHeaders,
    );
    final Map<String, dynamic> body = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        body['message']?.toString() ?? 'Could not load your XP.',
      );
    }

    return XpWeeklySummary.fromJson(body);
  }

  Future<List<LessonTopic>> fetchOnboardingTopics() async {
    final response = await http.get(Uri.parse('$baseUrl/onboarding/topics'));
    final Map<String, dynamic> body = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        body['message']?.toString() ?? 'Could not load onboarding.',
      );
    }

    final topics = body['topics'] as List<dynamic>;
    return topics
        .map((topic) => LessonTopic.fromJson(topic as Map<String, dynamic>))
        .toList();
  }

  Future<NotepadTreeNode> fetchNotepadTree(String accountId) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/notepad/tree',
      ).replace(queryParameters: {'accountId': accountId}),
      headers: ApiSession.authenticatedHeaders,
    );
    final Map<String, dynamic> body = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        body['message']?.toString() ?? 'Could not load notepad tree.',
      );
    }

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
    final Map<String, dynamic> body = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        body['message']?.toString() ?? 'Something went wrong.',
      );
    }
    return body;
  }
}

class GoogleAuthResult {
  const GoogleAuthResult({required this.account, required this.isNewUser});

  final Account account;
  final bool isNewUser;
}
