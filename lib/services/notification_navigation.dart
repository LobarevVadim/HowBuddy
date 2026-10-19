import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

class NotificationNavigation {
  NotificationNavigation._();

  static const _pendingTopicKey = 'pending_notification_topic_id';
  static String? _pendingTopicId;

  static Future<void> restore() async {
    final preferences = await SharedPreferences.getInstance();
    _pendingTopicId ??= preferences.getString(_pendingTopicKey);
  }

  static Future<void> remember(String topicId) async {
    if (topicId.isEmpty) return;
    _pendingTopicId = topicId;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_pendingTopicKey, topicId);
  }

  static String? take() {
    final topicId = _pendingTopicId;
    _pendingTopicId = null;
    if (topicId != null) {
      unawaited(
        SharedPreferences.getInstance().then(
          (preferences) => preferences.remove(_pendingTopicKey),
        ),
      );
    }
    return topicId;
  }

  static Future<void> restoreLinkedTopic(String? topicId) async {
    if (topicId != null && topicId.isNotEmpty) await remember(topicId);
  }

  static void resetForTest() => _pendingTopicId = null;
}
