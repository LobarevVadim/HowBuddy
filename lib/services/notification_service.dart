import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import 'api_session.dart';
import 'firebase_options.dart';
import 'notification_navigation.dart';
import 'notification_web_stub.dart'
    if (dart.library.js_interop) 'notification_web.dart'
    as browser;
import 'ui_translations.dart';

class ForegroundNotification {
  const ForegroundNotification({
    required this.title,
    required this.body,
    required this.topicId,
  });

  final String title;
  final String body;
  final String topicId;
}

class NotificationPreferences {
  const NotificationPreferences({
    required this.enabled,
    required this.curiosityEnabled,
    required this.quietHoursEnabled,
    required this.quietStartMinute,
    required this.quietEndMinute,
  });

  final bool enabled;
  final bool curiosityEnabled;
  final bool quietHoursEnabled;
  final int quietStartMinute;
  final int quietEndMinute;

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(
        enabled: json['enabled'] == true,
        curiosityEnabled: json['curiosityEnabled'] != false,
        quietHoursEnabled: json['quietHoursEnabled'] != false,
        quietStartMinute: int.tryParse('${json['quietStartMinute']}') ?? 1320,
        quietEndMinute: int.tryParse('${json['quietEndMinute']}') ?? 480,
      );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'curiosityEnabled': curiosityEnabled,
    'quietHoursEnabled': quietHoursEnabled,
    'quietStartMinute': quietStartMinute,
    'quietEndMinute': quietEndMinute,
  };
}

class NotificationService with WidgetsBindingObserver {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  final _topicTaps = StreamController<String>.broadcast();
  Stream<String> get topicTaps => _topicTaps.stream;
  final _foregroundNotifications =
      StreamController<ForegroundNotification>.broadcast();
  Stream<ForegroundNotification> get foregroundNotifications =>
      _foregroundNotifications.stream;

  FirebaseMessaging? _messaging;
  StreamSubscription<String>? _registrationSubscription;
  StreamSubscription<String>? _unregistrationSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  String? _activeAccountId;
  String? _activeRegistrationId;
  Completer<String>? _registrationCompleter;
  bool _initialized = false;
  bool _initializing = false;

  Future<bool> initialize() async {
    if (_initialized) return true;
    if (_initializing) return false;
    _initializing = true;
    try {
      final options = HowBuddyFirebaseOptions.current;
      if (options == null) return false;
      if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: options);
      _messaging = FirebaseMessaging.instance;
      await _messaging!.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      _messageSubscription = FirebaseMessaging.onMessage.listen(
        _onForegroundMessage,
      );
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _onOpenedMessage,
      );
      _registrationSubscription = _messaging!.onRegistered.listen(
        (registrationId) => unawaited(_handleRegistration(registrationId)),
      );
      _unregistrationSubscription = _messaging!.onUnregistered.listen((id) {
        if (_activeRegistrationId == id) _activeRegistrationId = null;
      });
      final initialMessage = await _messaging!.getInitialMessage();
      if (initialMessage != null) await _rememberTarget(initialMessage);
      await NotificationNavigation.restore();
      if (kIsWeb) {
        final linkedTopic = Uri.base.queryParameters['notificationTopic'];
        await NotificationNavigation.restoreLinkedTopic(linkedTopic);
      }
      WidgetsBinding.instance.addObserver(this);
      _initialized = true;
      return true;
    } catch (_) {
      // Missing Firebase platform configuration leaves notification controls usable
      // while gracefully disabling remote delivery.
      return false;
    } finally {
      _initializing = false;
    }
  }

  Future<bool> enable(String accountId) async {
    if (!await initialize() || _messaging == null) return false;
    try {
      final permission = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (permission.authorizationStatus != AuthorizationStatus.authorized &&
          permission.authorizationStatus != AuthorizationStatus.provisional) {
        return false;
      }
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        for (var attempt = 0; attempt < 10; attempt++) {
          if (await _messaging!.getAPNSToken() != null) break;
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
      }
      _activeAccountId = accountId;
      await _registerForPush();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> syncAccount(String accountId) async {
    await ApiSession.loadClientTimeZone();
    if (!await initialize() || _messaging == null) return;
    _activeAccountId = accountId;
    try {
      final permission = await _messaging!.getNotificationSettings();
      if (permission.authorizationStatus != AuthorizationStatus.authorized &&
          permission.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }
      await _registerForPush();
    } catch (_) {
      // A temporary FCM/network failure should not block signing in.
    }
  }

  Future<void> _registerToken(String accountId, String token) async {
    final zone = await FlutterTimezone.getLocalTimezone();
    final platform = kIsWeb
        ? 'web'
        : defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : 'android';
    await ApiSession.postJson('/account/notifications/device', {
      'token': token,
      'platform': platform,
      'timeZone': zone.identifier,
      'language': UiTranslations.languageCode,
    });
  }

  Future<void> _handleRegistration(String registrationId) async {
    _activeRegistrationId = registrationId;
    final accountId = _activeAccountId;
    if (accountId == null) return;
    try {
      await _registerToken(accountId, registrationId);
      final completer = _registrationCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.complete(registrationId);
      }
    } catch (error, stackTrace) {
      final completer = _registrationCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    }
  }

  Future<void> _registerForPush() async {
    final completer = Completer<String>();
    _registrationCompleter = completer;
    try {
      await _messaging!.register(
        vapidKey: kIsWeb ? HowBuddyFirebaseOptions.webVapidKey : null,
      );
      await completer.future.timeout(const Duration(seconds: 10));
    } finally {
      if (identical(_registrationCompleter, completer)) {
        _registrationCompleter = null;
      }
    }
  }

  Future<void> unregister(String accountId) async {
    _activeAccountId = null;
    try {
      final registrationId = _activeRegistrationId;
      if (registrationId != null) {
        await ApiSession.deleteJson('/account/notifications/device', {
          'token': registrationId,
        });
      }
      await _messaging?.unregister();
    } catch (_) {
      // The session may already be offline; the server can expire stale FCM tokens.
    }
  }

  String? takePendingTopicId() {
    return NotificationNavigation.take();
  }

  Future<void> _onOpenedMessage(RemoteMessage message) async {
    await _rememberTarget(message);
  }

  Future<void> _rememberTarget(RemoteMessage message) async {
    final topicId = message.data['topicId']?.toString();
    if (topicId == null || topicId.isEmpty) return;
    await NotificationNavigation.remember(topicId);
    _topicTaps.add(topicId);
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    final title = notification.title ?? 'HowBuddy';
    final body = notification.body ?? '';
    final topicId = message.data['topicId']?.toString() ?? '';
    browser.showBrowserNotification(title, body, topicId);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _foregroundNotifications.add(
        ForegroundNotification(title: title, body: body, topicId: topicId),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _activeAccountId != null) {
      unawaited(syncAccount(_activeAccountId!));
    }
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _registrationSubscription?.cancel();
    await _unregistrationSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _topicTaps.close();
    await _foregroundNotifications.close();
  }
}
