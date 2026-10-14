import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../services/google_identity.dart';
import '../../services/ui_translations.dart';
import '../../shared/app_widgets.dart';

class GoogleAuthButton extends StatefulWidget {
  const GoogleAuthButton({
    required this.isSignup,
    required this.isLoading,
    required this.onIdToken,
    required this.onError,
    super.key,
  });

  final bool isSignup;
  final bool isLoading;
  final ValueChanged<String> onIdToken;
  final ValueChanged<String> onError;

  @override
  State<GoogleAuthButton> createState() => _GoogleAuthButtonState();
}

class _GoogleAuthButtonState extends State<GoogleAuthButton> {
  Future<void> _signIn() async {
    try {
      final idToken = await GoogleSignInFlow.authenticate();
      if (mounted) widget.onIdToken(idToken);
    } on GoogleSignInException catch (error) {
      if (!mounted || error.code == GoogleSignInExceptionCode.canceled) return;
      widget.onError(error.description ?? 'Google sign-in could not start.');
    } catch (_) {
      if (mounted) widget.onError('Google sign-in could not start.');
    }
  }

  @override
  Widget build(BuildContext context) => SocialButton(
    text: widget.isSignup
        ? uiText(context, 'Sign up with Google')
        : uiText(context, 'Sign in with Google'),
    icon: Icons.g_mobiledata_rounded,
    iconColor: const Color(0xFF4285F4),
    onPressed: _signIn,
    isLoading: widget.isLoading,
  );
}
