import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInFlow {
  GoogleSignInFlow._();

  static const webClientId =
      '533985639406-lpjq93u5eos638fc0rsf1tjkhq1157o0.apps.googleusercontent.com';
  static const iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  static Future<void>? _initialization;

  static Future<void> initialize() =>
      _initialization ??= GoogleSignIn.instance.initialize(
        clientId: kIsWeb
            ? webClientId
            : defaultTargetPlatform == TargetPlatform.iOS
            ? (iosClientId.isEmpty ? null : iosClientId)
            : null,
        serverClientId: kIsWeb ? null : webClientId,
      );

  static Future<String> authenticate() async {
    await initialize();
    final user = await GoogleSignIn.instance.authenticate();
    final token = user.authentication.idToken;
    if (token == null || token.isEmpty) {
      throw const GoogleIdentityException(
        'Google did not return a sign-in token.',
      );
    }
    return token;
  }
}

class GoogleIdentityException implements Exception {
  const GoogleIdentityException(this.message);

  final String message;
}
