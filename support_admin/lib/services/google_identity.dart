import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInFlow {
  GoogleSignInFlow._();

  static const webClientId =
      '533985639406-lpjq93u5eos638fc0rsf1tjkhq1157o0.apps.googleusercontent.com';

  static Future<void>? _initialization;

  static Future<void> initialize() => _initialization ??= GoogleSignIn.instance
      .initialize(clientId: webClientId);
}
