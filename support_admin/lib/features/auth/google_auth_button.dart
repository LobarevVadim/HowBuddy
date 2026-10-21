import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;

import '../../services/google_identity.dart';

class GoogleAuthButton extends StatefulWidget {
  const GoogleAuthButton({
    required this.isLoading,
    required this.onIdToken,
    required this.onError,
    super.key,
  });

  final bool isLoading;
  final ValueChanged<String> onIdToken;
  final ValueChanged<String> onError;

  @override
  State<GoogleAuthButton> createState() => _GoogleAuthButtonState();
}

class _GoogleAuthButtonState extends State<GoogleAuthButton> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _subscription;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      await GoogleSignInFlow.initialize();
      _subscription = GoogleSignIn.instance.authenticationEvents.listen(
        (event) {
          if (event is! GoogleSignInAuthenticationEventSignIn) return;
          final token = event.user.authentication.idToken;
          if (token == null || token.isEmpty) {
            widget.onError('Google did not return a sign-in token.');
          } else {
            widget.onIdToken(token);
          }
        },
        onError: (Object _) =>
            widget.onError('Google sign-in could not complete.'),
      );
      if (mounted) setState(() => _isReady = true);
    } catch (_) {
      if (mounted) widget.onError('Google sign-in could not be initialized.');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const SizedBox(
        height: 44,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return SizedBox(
      height: 44,
      child: IgnorePointer(
        ignoring: widget.isLoading,
        child: google_web.renderButton(
          configuration: google_web.GSIButtonConfiguration(
            type: google_web.GSIButtonType.standard,
            theme: google_web.GSIButtonTheme.outline,
            size: google_web.GSIButtonSize.large,
            text: google_web.GSIButtonText.signinWith,
            shape: google_web.GSIButtonShape.rectangular,
            minimumWidth: 260,
          ),
        ),
      ),
    );
  }
}
