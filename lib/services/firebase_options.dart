import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class HowBuddyFirebaseOptions {
  const HowBuddyFirebaseOptions._();

  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const _webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const _androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');

  static FirebaseOptions? get current {
    if (_apiKey.isEmpty || _projectId.isEmpty || _senderId.isEmpty) return null;
    final appId = kIsWeb
        ? _webAppId
        : defaultTargetPlatform == TargetPlatform.iOS
        ? _iosAppId
        : _androidAppId;
    if (appId.isEmpty) return null;
    return FirebaseOptions(
      apiKey: _apiKey,
      appId: appId,
      messagingSenderId: _senderId,
      projectId: _projectId,
      authDomain: const String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
      storageBucket: const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
      iosBundleId: const String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
      measurementId: const String.fromEnvironment('FIREBASE_MEASUREMENT_ID'),
    );
  }

  static const webVapidKey = String.fromEnvironment('FIREBASE_WEB_VAPID_KEY');
}
