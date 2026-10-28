import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import 'api_session.dart';
import 'async_resource_ownership.dart';
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
  final _ownership = SessionWorkOwnership(
    generation: () => ApiSession.generation,
  );
  String? get _activeAccountId => _ownership.current?.accountId;
  int? get _activeGeneration => _ownership.current?.generation;
  int get _accountEpoch => _ownership.epoch;
  String? _activeRegistrationId;
  Completer<String>? _registrationCompleter;
  ({String accountId, int generation, int epoch})? _registrationScope;
  final _registrationRuns =
      SerialSingleFlight<
        ({String accountId, int generation, int epoch}),
        void
      >();
  bool _initialized = false;
  bool _disposed = false;
  Future<bool>? _initializationFuture;

  Future<bool> initialize() {
    if (_disposed) return Future.value(false);
    if (_initialized) return Future.value(true);
    return _initializationFuture ??= _initialize().whenComplete(() {
      _initializationFuture = null;
    });
  }

  Future<bool> _initialize() async {
    try {
      final options = HowBuddyFirebaseOptions.current;
      if (options == null) return false;
      if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: options);
      if (_disposed) return false;
      _messaging = FirebaseMessaging.instance;
      await _messaging!.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (_disposed) return false;
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
      if (_disposed) return false;
      if (initialMessage != null) await _rememberTarget(initialMessage);
      await NotificationNavigation.restore();
      if (_disposed) return false;
      if (kIsWeb) {
        final linkedTopic = Uri.base.queryParameters['notificationTopic'];
        await NotificationNavigation.restoreLinkedTopic(linkedTopic);
      }
      if (_disposed) return false;
      WidgetsBinding.instance.addObserver(this);
      _initialized = true;
      return true;
    } catch (_) {
      // Missing Firebase platform configuration leaves notification controls usable
      // while gracefully disabling remote delivery.
      return false;
    } finally {
      if (!_initialized) await _cancelSubscriptions();
    }
  }

  ({String accountId, int generation, int epoch}) _activate(String accountId) {
    final previous = _ownership.current;
    final scope = _ownership.activate(accountId);
    if (scope != previous) _cancelRegistration();
    return scope;
  }

  bool _isCurrent(({String accountId, int generation, int epoch}) scope) =>
      !_disposed && _ownership.owns(scope);

  void _cancelRegistration() {
    final pending = _registrationCompleter;
    if (pending != null && !pending.isCompleted) pending.complete('');
  }

  Future<bool> enable(String accountId) async {
    final scope = _activate(accountId);
    if (!await initialize() || !_isCurrent(scope) || _messaging == null) {
      return false;
    }
    try {
      final permission = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (!_isCurrent(scope)) return false;
      if (permission.authorizationStatus != AuthorizationStatus.authorized &&
          permission.authorizationStatus != AuthorizationStatus.provisional) {
        return false;
      }
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        for (var attempt = 0; attempt < 10; attempt++) {
          final token = await _messaging!.getAPNSToken();
          if (!_isCurrent(scope)) return false;
          if (token != null) break;
          await Future<void>.delayed(const Duration(milliseconds: 300));
          if (!_isCurrent(scope)) return false;
        }
      }
      await _registerForPush(scope);
      return _isCurrent(scope);
    } catch (_) {
      return false;
    }
  }

  Future<void> syncAccount(String accountId) async {
    final scope = _activate(accountId);
    await ApiSession.loadClientTimeZone();
    if (!_isCurrent(scope) ||
        !await initialize() ||
        !_isCurrent(scope) ||
        _messaging == null) {
      return;
    }
    try {
      final permission = await _messaging!.getNotificationSettings();
      if (!_isCurrent(scope)) return;
      if (permission.authorizationStatus != AuthorizationStatus.authorized &&
          permission.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }
      await _registerForPush(scope);
    } catch (_) {
      // A temporary FCM/network failure should not block signing in.
    }
  }

  Future<void> _registerToken(
    ({String accountId, int generation, int epoch}) scope,
    String token,
  ) async {
    final zone = await FlutterTimezone.getLocalTimezone();
    // Capture authentication only after confirming the original session still
    // owns this operation; timezone lookup can outlive logout/account switch.
    if (!_isCurrent(scope)) return;
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
    final accountId = _activeAccountId;
    final generation = _activeGeneration;
    if (accountId == null || generation == null) return;
    final scope =
        _registrationScope ??
        (accountId: accountId, generation: generation, epoch: _accountEpoch);
    final completer = _registrationCompleter;
    if (!_isCurrent(scope)) return;
    try {
      await _registerToken(scope, registrationId);
      if (!_isCurrent(scope)) return;
      _activeRegistrationId = registrationId;
      if (completer != null && !completer.isCompleted) {
        completer.complete(registrationId);
      }
    } catch (error, stackTrace) {
      if (!_isCurrent(scope)) return;
      if (completer != null && !completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    }
  }

  Future<void> _registerForPush(
    ({String accountId, int generation, int epoch}) scope,
  ) => _registrationRuns.run(scope, () => _performRegistration(scope));

  Future<void> _performRegistration(
    ({String accountId, int generation, int epoch}) scope,
  ) async {
    if (!_isCurrent(scope)) return;
    final completer = Completer<String>();
    _registrationCompleter = completer;
    _registrationScope = scope;
    // Attach the listener before platform registration can synchronously emit
    // an error. The deadline bounds both native registration and token upload.
    final completed = completer.future.timeout(const Duration(seconds: 10));
    try {
      unawaited(
        Future<void>.sync(
          () => _messaging!.register(
            vapidKey: kIsWeb ? HowBuddyFirebaseOptions.webVapidKey : null,
          ),
        ).catchError((Object error, StackTrace stack) {
          if (!completer.isCompleted) completer.completeError(error, stack);
        }),
      );
      await completed;
    } finally {
      if (identical(_registrationCompleter, completer)) {
        _registrationCompleter = null;
        _registrationScope = null;
      }
    }
  }

  Future<void> unregister(String accountId) async {
    if (_activeAccountId != accountId ||
        _activeGeneration != ApiSession.generation) {
      return;
    }
    final generation = ApiSession.generation;
    final epoch = _ownership.invalidate();
    _cancelRegistration();
    try {
      final registrationId = _activeRegistrationId;
      if (registrationId != null) {
        await ApiSession.deleteJson('/account/notifications/device', {
          'token': registrationId,
        });
      }
      if (_accountEpoch != epoch || ApiSession.generation != generation) return;
      await _registrationRuns.run(
        (accountId: accountId, generation: generation, epoch: epoch),
        () async {
          if (_accountEpoch != epoch || ApiSession.generation != generation) {
            return;
          }
          await _messaging?.unregister();
        },
      );
      if (_accountEpoch == epoch) _activeRegistrationId = null;
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
    if (!_topicTaps.isClosed) _topicTaps.add(topicId);
  }

  void _onForegroundMessage(RemoteMessage message) {
    if (_disposed) return;
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
    _disposed = true;
    _ownership.invalidate();
    _cancelRegistration();
    WidgetsBinding.instance.removeObserver(this);
    await _cancelSubscriptions();
    await _topicTaps.close();
    await _foregroundNotifications.close();
  }

  Future<void> _cancelSubscriptions() async {
    await _registrationSubscription?.cancel();
    await _unregistrationSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _openedSubscription?.cancel();
    _registrationSubscription = null;
    _unregistrationSubscription = null;
    _messageSubscription = null;
    _openedSubscription = null;
  }
}
