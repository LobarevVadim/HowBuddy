import 'package:flutter/material.dart';

import '../../app_style.dart';
import '../../models/app_models.dart';
import '../../services/auth_api.dart';
import '../../services/api_session.dart';
import '../../shared/app_widgets.dart';
import 'google_auth_button.dart';
import 'account_preferences_page.dart';
import '../home/home_page.dart';
import '../../services/theme_preferences.dart';
import '../../services/ui_translations.dart';

void _returnToLogin(NavigatorState navigator) {
  ApiSession.clear();
  navigator.pushReplacement(
    MaterialPageRoute(builder: (_) => const LoginPage()),
  );
}

Widget _accountDestination(
  Account account,
  NavigatorState navigator, {
  required bool isNewUser,
}) {
  Widget nextPage(Account savedAccount) => isNewUser
      ? OnboardingPage(account: savedAccount)
      : HomePage(
          account: savedAccount,
          onLogout: () => _returnToLogin(navigator),
        );

  if (account.preferredLanguage == null || account.ageYears == null) {
    return AccountPreferencesPage(
      account: account,
      nextPageBuilder: (_, savedAccount) => nextPage(savedAccount),
    );
  }
  return nextPage(account);
}

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _authApi = AuthApi();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final account = await _authApi.register(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }
      final navigator = Navigator.of(context);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              _accountDestination(account, navigator, isNewUser: true),
        ),
      );
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Could not reach the account server.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(uiText(context, message))));
  }

  Future<void> _signUpWithGoogle(String idToken) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final result = await _authApi.googleSignIn(
        idToken: idToken,
        allowRegistration: true,
      );
      if (!mounted) return;
      final navigator = Navigator.of(context);
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => _accountDestination(
            result.account,
            navigator,
            isNewUser: result.isNewUser,
          ),
        ),
      );
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Could not reach the account server.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemePreferencesScope.watch(context);
    return AuthScaffold(
      title: uiText(context, 'Create your account'),
      subtitle: uiText(context, 'Join HowBuddy and start your journey!'),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _fullNameController,
              label: uiText(context, 'Full Name'),
              icon: Icons.badge_outlined,
              validator: (value) => value == null || value.trim().length < 2
                  ? uiText(context, 'Enter your full name.')
                  : null,
            ),
            const SizedBox(height: AppSpacing.fieldGap),
            AppTextField(
              controller: _emailController,
              label: uiText(context, 'Email Address'),
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                final error = validateEmailInput(value);
                return error == null ? null : uiText(context, error);
              },
            ),
            const SizedBox(height: AppSpacing.fieldGap),
            AppTextField(
              controller: _passwordController,
              label: uiText(context, 'Password'),
              icon: Icons.lock_outline,
              obscureText: true,
              showPasswordToggle: true,
              translatePasswordToggle: true,
              validator: (value) {
                final error = validatePasswordInput(value);
                return error == null ? null : uiText(context, error);
              },
            ),
            const SizedBox(height: AppSpacing.fieldGap),
            AppTextField(
              controller: _confirmPasswordController,
              label: uiText(context, 'Confirm Password'),
              icon: Icons.verified_user_outlined,
              obscureText: true,
              showPasswordToggle: true,
              translatePasswordToggle: true,
              validator: (value) {
                if (value != _passwordController.text) {
                  return uiText(context, 'Passwords do not match.');
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.passwordTipGap),
            const PasswordTipCard(localized: true),
            const SizedBox(height: AppSpacing.sectionGap),
            PrimaryButton(
              text: uiText(context, 'Sign up'),
              isLoading: _isLoading,
              onPressed: _submit,
            ),
            const AuthDivider(translate: true),
            GoogleAuthButton(
              isSignup: true,
              isLoading: _isLoading,
              onIdToken: _signUpWithGoogle,
              onError: _showMessage,
            ),
            const SizedBox(height: AppSpacing.socialButtonGap),
            SocialButton(
              text: uiText(context, 'Sign up with Apple (coming soon)'),
              icon: Icons.apple,
              iconColor: AppColors.apple,
              onPressed: () {},
              isEnabled: false,
            ),
            const SizedBox(height: AppSpacing.authSwitchGap),
            AuthSwitchText(
              text: uiText(context, 'Already have an account?'),
              linkText: uiText(context, 'Login'),
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({required this.account, super.key});

  final Account account;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late final Future<List<LessonTopic>> _topics = AuthApi()
      .fetchOnboardingTopics();

  void _openTopic(LessonTopic topic) {
    final navigator = Navigator.of(context);
    navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomePage(
          account: widget.account,
          topicId: topic.id,
          onLogout: () => _returnToLogin(navigator),
        ),
      ),
    );
  }

  void _skipToNotepad() {
    final navigator = Navigator.of(context);
    navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomePage(
          account: widget.account,
          initialIndex: 1,
          onLogout: () => _returnToLogin(navigator),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ThemePreferencesScope.watch(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.tabPagePadding),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthHeroImage(),
                  const SizedBox(height: AppSpacing.heroGap),
                  Text(
                    uiText(context, 'Where do we want to start?'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.contentGap),
                  FutureBuilder<List<LessonTopic>>(
                    future: _topics,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const TreePanel(
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (snapshot.hasError) {
                        return Text(
                          uiText(context, 'Could not load questions.'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: AppColors.mutedText),
                        );
                      }

                      final topics = snapshot.data ?? [];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final topic in topics) ...[
                            OnboardingOptionButton(
                              title: topic.question,
                              subtitle: uiText(
                                context,
                                '{count} lessons',
                                args: {'count': '${topic.lessonCount}'},
                              ),
                              onPressed: () => _openTopic(topic),
                            ),
                            const SizedBox(height: AppSpacing.socialButtonGap),
                          ],
                          OutlinedButton.icon(
                            onPressed: _skipToNotepad,
                            icon: const Icon(Icons.note_alt_outlined),
                            label: Text(
                              uiText(context, 'Skip to the main tree'),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryDark,
                              side: BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadii.button,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingOptionButton extends StatelessWidget {
  const OnboardingOptionButton({
    required this.title,
    required this.subtitle,
    required this.onPressed,
    super.key,
  });

  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    ThemePreferencesScope.watch(context);
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.eco_rounded, color: AppColors.success),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _authApi = AuthApi();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final account = await _authApi.login(
        identifier: _identifierController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }
      final navigator = Navigator.of(context);
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              _accountDestination(account, navigator, isNewUser: false),
        ),
      );
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Could not reach the account server.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(uiText(context, message))));
  }

  String? _validateLoginPassword(String? value) {
    if (value == null || value.length < 8) {
      return uiText(context, 'Password must be at least 8 characters.');
    }
    return null;
  }

  Future<void> _signInWithGoogle(String idToken) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final result = await _authApi.googleSignIn(
        idToken: idToken,
        allowRegistration: false,
      );
      if (!mounted) return;
      final navigator = Navigator.of(context);
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              _accountDestination(result.account, navigator, isNewUser: false),
        ),
      );
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Could not reach the account server.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemePreferencesScope.watch(context);
    return AuthScaffold(
      title: uiText(context, 'Welcome back!'),
      subtitle: uiText(context, 'Login to continue your journey'),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _identifierController,
              label: uiText(context, 'Email or Username'),
              icon: Icons.account_circle_outlined,
              validator: (value) => value == null || value.trim().isEmpty
                  ? uiText(context, 'Enter your email or username.')
                  : null,
            ),
            const SizedBox(height: AppSpacing.fieldGap),
            AppTextField(
              controller: _passwordController,
              label: uiText(context, 'Password'),
              icon: Icons.lock_outline,
              obscureText: true,
              showPasswordToggle: true,
              translatePasswordToggle: true,
              validator: _validateLoginPassword,
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            PrimaryButton(
              text: uiText(context, 'Login'),
              isLoading: _isLoading,
              onPressed: _submit,
            ),
            const AuthDivider(translate: true),
            GoogleAuthButton(
              isSignup: false,
              isLoading: _isLoading,
              onIdToken: _signInWithGoogle,
              onError: _showMessage,
            ),
            const SizedBox(height: AppSpacing.socialButtonGap),
            SocialButton(
              text: uiText(context, 'Sign in with Apple (coming soon)'),
              icon: Icons.apple,
              iconColor: AppColors.apple,
              onPressed: () {},
              isEnabled: false,
            ),
            const SizedBox(height: AppSpacing.authSwitchGap),
            AuthSwitchText(
              text: uiText(context, "Don't have an account?"),
              linkText: uiText(context, 'Sign Up'),
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const RegistrationPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
