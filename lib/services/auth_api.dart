import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_models.dart';

class AuthApi {
  AuthApi({
    this.baseUrl = const String.fromEnvironment(
      'API_URL',
      defaultValue: 'http://localhost:3000',
    ),
  });

  final String baseUrl;

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

  Future<List<LessonLevel>> fetchLessonLevels() async {
    final response = await http.get(Uri.parse('$baseUrl/lessons/tree'));
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

  Future<TreeData> fetchTreeData(String topicId) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/lessons/tree',
      ).replace(queryParameters: {'topic': topicId}),
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
        .map((question) => question.toString())
        .toList();
    final topic = LessonTopic.fromJson(body['topic'] as Map<String, dynamic>);

    return TreeData(topic: topic, levels: levels, nextQuestions: nextQuestions);
  }

  Future<LessonCompletion> completeLesson({
    required String topicId,
    required String lessonId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/lessons/complete'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'topicId': topicId, 'lessonId': lessonId}),
    );
    final Map<String, dynamic> body = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        body['message']?.toString() ?? 'Could not complete lesson.',
      );
    }

    return LessonCompletion.fromJson(body);
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

  Future<NotepadTreeNode> fetchNotepadTree() async {
    final response = await http.get(Uri.parse('$baseUrl/notepad/tree'));
    final Map<String, dynamic> body = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        body['message']?.toString() ?? 'Could not load notepad tree.',
      );
    }

    return NotepadTreeNode.fromJson(body['tree'] as Map<String, dynamic>);
  }

  Account _readAccount(http.Response response) {
    final Map<String, dynamic> body = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        body['message']?.toString() ?? 'Something went wrong.',
      );
    }

    return Account.fromJson(body['account'] as Map<String, dynamic>);
  }
}
