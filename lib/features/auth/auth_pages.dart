import 'package:flutter/material.dart';

import '../../app_style.dart';
import '../../models/app_models.dart';
import '../../services/auth_api.dart';
import '../../services/api_session.dart';
import '../../shared/app_widgets.dart';
import 'google_auth_button.dart';
import '../home/home_page.dart';
import '../../services/theme_preferences.dart';

void _returnToLogin(NavigatorState navigator) {
  ApiSession.clear();
  navigator.pushReplacement(
    MaterialPageRoute(builder: (_) => const LoginPage()),
  );
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OnboardingPage(account: account)),
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
    ).showSnackBar(SnackBar(content: Text(message)));
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
      if (result.isNewUser) {
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (_) => OnboardingPage(account: result.account),
          ),
        );
      } else {
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomePage(
              account: result.account,
              onLogout: () => _returnToLogin(navigator),
            ),
          ),
        );
      }
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
      title: 'Create your account',
      subtitle: 'Join HowBuddy and start your journey!',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _fullNameController,
              label: 'Full Name',
              icon: Icons.badge_outlined,
              validator: (value) => value == null || value.trim().length < 2
                  ? 'Enter your full name.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.fieldGap),
            AppTextField(
              controller: _emailController,
              label: 'Email Address',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              validator: validateEmailInput,
            ),
            const SizedBox(height: AppSpacing.fieldGap),
            AppTextField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline,
              obscureText: true,
              showPasswordToggle: true,
              validator: validatePasswordInput,
            ),
            const SizedBox(height: AppSpacing.fieldGap),
            AppTextField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              icon: Icons.verified_user_outlined,
              obscureText: true,
              showPasswordToggle: true,
              validator: (value) {
                if (value != _passwordController.text) {
                  return 'Passwords do not match.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.passwordTipGap),
            const PasswordTipCard(),
            const SizedBox(height: AppSpacing.sectionGap),
            PrimaryButton(
              text: 'Sign up',
              isLoading: _isLoading,
              onPressed: _submit,
            ),
            const AuthDivider(),
            GoogleAuthButton(
              isSignup: true,
              isLoading: _isLoading,
              onIdToken: _signUpWithGoogle,
              onError: _showMessage,
            ),
            const SizedBox(height: AppSpacing.socialButtonGap),
            SocialButton(
              text: 'Sign up with Apple (coming soon)',
              icon: Icons.apple,
              iconColor: AppColors.apple,
              onPressed: () {},
              isEnabled: false,
            ),
            const SizedBox(height: AppSpacing.authSwitchGap),
            AuthSwitchText(
              text: 'Already have an account?',
              linkText: 'Login',
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
                    'Where do we want to start?',
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
                          'Could not load questions.',
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
                              subtitle: '${topic.lessonCount} lessons',
                              onPressed: () => _openTopic(topic),
                            ),
                            const SizedBox(height: AppSpacing.socialButtonGap),
                          ],
                          OutlinedButton.icon(
                            onPressed: _skipToNotepad,
                            icon: const Icon(Icons.note_alt_outlined),
                            label: const Text('Skip to the main tree'),
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
          builder: (_) => HomePage(
            account: account,
            onLogout: () => _returnToLogin(navigator),
          ),
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
    ).showSnackBar(SnackBar(content: Text(message)));
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
          builder: (_) => HomePage(
            account: result.account,
            onLogout: () => _returnToLogin(navigator),
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
      title: 'Welcome back!',
      subtitle: 'Login to continue your journey',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _identifierController,
              label: 'Email or Username',
              icon: Icons.account_circle_outlined,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter your email or username.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.fieldGap),
            AppTextField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline,
              obscureText: true,
              showPasswordToggle: true,
              validator: validatePasswordInput,
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            PrimaryButton(
              text: 'Login',
              isLoading: _isLoading,
              onPressed: _submit,
            ),
            const AuthDivider(),
            GoogleAuthButton(
              isSignup: false,
              isLoading: _isLoading,
              onIdToken: _signInWithGoogle,
              onError: _showMessage,
            ),
            const SizedBox(height: AppSpacing.socialButtonGap),
            SocialButton(
              text: 'Sign in with Apple (coming soon)',
              icon: Icons.apple,
              iconColor: AppColors.apple,
              onPressed: () {},
              isEnabled: false,
            ),
            const SizedBox(height: AppSpacing.authSwitchGap),
            AuthSwitchText(
              text: 'Don\'t have an account?',
              linkText: 'Sign Up',
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
