import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_style.dart';

void main() {
  runApp(const HowBuddyApp());
}

class HowBuddyApp extends StatelessWidget {
  const HowBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HowBuddy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const LoadingPage(),
    );
  }
}

class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.loadingBackground,
      body: SafeArea(
        child: Center(
          child: Image(
            image: AssetImage('assets/images/howbuddy_loading.jpg'),
            fit: BoxFit.contain,
            width: double.infinity,
          ),
        ),
      ),
    );
  }
}

class AuthApi {
  AuthApi({
    this.baseUrl = const String.fromEnvironment(
      'API_URL',
      defaultValue: 'http://localhost:3000',
    ),
  });

  final String baseUrl;

  Future<Account> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fullName': fullName,
        'email': email,
        'password': password,
      }),
    );

    return _readAccount(response);
  }

  Future<Account> login({
    required String identifier,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier, 'password': password}),
    );

    return _readAccount(response);
  }

  Future<Account> socialSignUp({
    required String provider,
    required String displayName,
    required String email,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/social-signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'provider': provider,
        'displayName': displayName,
        'email': email,
      }),
    );

    return _readAccount(response);
  }

  Account _readAccount(http.Response response) {
    final Map<String, dynamic> body = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        body['message']?.toString() ?? 'Something went wrong.',
      );
    }

    return Account.fromJson(body['account'] as Map<String, dynamic>);
  }
}

class Account {
  const Account({
    required this.id,
    required this.fullName,
    required this.email,
  });

  final String id;
  final String fullName;
  final String email;

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'].toString(),
      fullName: json['fullName'].toString(),
      email: json['email'].toString(),
    );
  }
}

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
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
  String? _socialProviderLoading;

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
        MaterialPageRoute(builder: (_) => HomePage(account: account)),
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

  Future<void> _socialSignUp(String provider) async {
    setState(() => _socialProviderLoading = provider);
    try {
      final account = await _authApi.socialSignUp(
        provider: provider,
        displayName: provider == 'google' ? 'Google User' : 'Apple User',
        email: provider == 'google'
            ? 'google.user@howbuddy.local'
            : 'apple.user@howbuddy.local',
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomePage(account: account)),
      );
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Could not reach the account server.');
    } finally {
      if (mounted) {
        setState(() => _socialProviderLoading = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              validator: _validateEmail,
            ),
            const SizedBox(height: AppSpacing.fieldGap),
            AppTextField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline,
              obscureText: true,
              showPasswordToggle: true,
              validator: _validatePassword,
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
            SocialButton(
              text: 'Sign up with Google',
              icon: Icons.g_mobiledata_rounded,
              iconColor: AppColors.google,
              isLoading: _socialProviderLoading == 'google',
              onPressed: () => _socialSignUp('google'),
            ),
            const SizedBox(height: AppSpacing.socialButtonGap),
            SocialButton(
              text: 'Sign up with Apple',
              icon: Icons.apple,
              iconColor: AppColors.apple,
              isLoading: _socialProviderLoading == 'apple',
              onPressed: () => _socialSignUp('apple'),
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomePage(account: account)),
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

  @override
  Widget build(BuildContext context) {
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
              validator: _validatePassword,
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            PrimaryButton(
              text: 'Login',
              isLoading: _isLoading,
              onPressed: _submit,
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

class HomePage extends StatefulWidget {
  const HomePage({required this.account, super.key});

  final Account account;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  void _selectTab(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const TreeLessonsPage(),
      const SignedInTabPage(
        icon: Icons.note_alt_outlined,
        title: 'Notepad',
        subtitle: 'Capture thoughts, plans, and ideas.',
      ),
      const SignedInTabPage(
        icon: Icons.workspace_premium_outlined,
        title: 'XP',
        subtitle: 'Track progress and keep building momentum.',
      ),
      ProfileTabPage(account: widget.account),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.park_outlined),
            selectedIcon: Icon(Icons.park_rounded),
            label: 'Tree',
          ),
          NavigationDestination(
            icon: Icon(Icons.note_alt_outlined),
            selectedIcon: Icon(Icons.note_alt_rounded),
            label: 'Notepad',
          ),
          NavigationDestination(
            icon: Icon(Icons.workspace_premium_outlined),
            selectedIcon: Icon(Icons.workspace_premium_rounded),
            label: 'XP',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class TreeLessonsPage extends StatelessWidget {
  const TreeLessonsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.tabPagePadding),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: AppColors.authPanelBackground,
                  borderRadius: BorderRadius.circular(AppRadii.heroImage),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SECTION 1, UNIT 1',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.mutedText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.titleGap),
                    Text(
                      'Could we be immortal?',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              Container(
                height: 620,
                decoration: BoxDecoration(
                  color: AppColors.authPanelBackground,
                  borderRadius: BorderRadius.circular(AppRadii.heroImage),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Stack(
                  children: [
                    Positioned.fill(child: LessonTree()),
                    Positioned(
                      left: 26,
                      top: 28,
                      child: LessonMascot(size: 108),
                    ),
                    Positioned(
                      right: 34,
                      bottom: 46,
                      child: LessonMascot(size: 104),
                    ),
                    LessonNode(
                      alignment: Alignment(0.10, -0.88),
                      icon: Icons.star_border_rounded,
                    ),
                    LessonNode(
                      alignment: Alignment(-0.43, -0.50),
                      icon: Icons.change_history_rounded,
                    ),
                    LessonNode(
                      alignment: Alignment(0.46, -0.36),
                      icon: Icons.hexagon_outlined,
                    ),
                    LessonNode(
                      alignment: Alignment(-0.50, 0.06),
                      icon: Icons.crop_square_rounded,
                    ),
                    LessonNode(
                      alignment: Alignment(0.56, 0.32),
                      icon: Icons.circle_outlined,
                    ),
                    LessonNode(
                      alignment: Alignment(-0.43, 0.58),
                      icon: Icons.star_border_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LessonTree extends StatelessWidget {
  const LessonTree({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: LessonTreePainter());
  }
}

class LessonTreePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final branchPaint = Paint()
      ..color = AppColors.primaryLight
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10;
    final leafPaint = Paint()
      ..color = AppColors.success
      ..style = PaintingStyle.fill;
    final trunkX = size.width * 0.50;
    final topY = size.height * 0.16;
    final bottomY = size.height * 0.96;

    canvas.drawLine(Offset(trunkX, topY), Offset(trunkX, bottomY), branchPaint);
    _drawBranch(
      canvas,
      branchPaint,
      Offset(trunkX, size.height * 0.26),
      Offset(size.width * 0.31, size.height * 0.32),
    );
    _drawBranch(
      canvas,
      branchPaint,
      Offset(trunkX, size.height * 0.39),
      Offset(size.width * 0.67, size.height * 0.43),
    );
    _drawBranch(
      canvas,
      branchPaint,
      Offset(trunkX, size.height * 0.58),
      Offset(size.width * 0.29, size.height * 0.55),
    );
    _drawBranch(
      canvas,
      branchPaint,
      Offset(trunkX, size.height * 0.72),
      Offset(size.width * 0.74, size.height * 0.65),
    );
    _drawBranch(
      canvas,
      branchPaint,
      Offset(trunkX, size.height * 0.82),
      Offset(size.width * 0.31, size.height * 0.77),
    );

    for (final leaf in [
      Offset(size.width * 0.45, size.height * 0.20),
      Offset(size.width * 0.57, size.height * 0.27),
      Offset(size.width * 0.37, size.height * 0.39),
      Offset(size.width * 0.73, size.height * 0.46),
      Offset(size.width * 0.46, size.height * 0.53),
      Offset(size.width * 0.34, size.height * 0.65),
      Offset(size.width * 0.57, size.height * 0.77),
    ]) {
      canvas.save();
      canvas.translate(leaf.dx, leaf.dy);
      canvas.rotate(-0.6);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 18, height: 28),
        leafPaint,
      );
      canvas.restore();
    }
  }

  void _drawBranch(Canvas canvas, Paint paint, Offset start, Offset end) {
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo((start.dx + end.dx) / 2, start.dy, end.dx, end.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LessonNode extends StatelessWidget {
  const LessonNode({required this.alignment, required this.icon, super.key});

  final Alignment alignment;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.primaryLight, width: 4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F6F482C),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.primary, size: 42),
      ),
    );
  }
}

class LessonMascot extends StatelessWidget {
  const LessonMascot({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/howbuddy_mascot.jpg',
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
  }
}

class SignedInTabPage extends StatelessWidget {
  const SignedInTabPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.tabPagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: AppSizes.tabHeroIcon),
            const SizedBox(height: AppSpacing.tabIconGap),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.tabTextGap),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileTabPage extends StatelessWidget {
  const ProfileTabPage({required this.account, super.key});

  final Account account;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.tabPagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_rounded,
              color: AppColors.success,
              size: AppSizes.tabHeroIcon,
            ),
            const SizedBox(height: AppSpacing.tabIconGap),
            Text(
              'Hi, ${account.fullName}',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.tabTextGap),
            Text(
              account.email,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.mutedText),
            ),
            const SizedBox(height: AppSpacing.profileLogoutGap),
            PrimaryButton(
              text: 'Logout',
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

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide =
                constraints.maxWidth >= AppSizes.wideLayoutBreakpoint;
            final content = ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.authContentMaxWidth,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide
                      ? AppSpacing.pageHorizontalWide
                      : AppSpacing.pageHorizontal,
                  vertical: AppSpacing.pageVertical,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AuthHeroImage(),
                    const SizedBox(height: AppSpacing.heroGap),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: AppColors.text,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.titleGap),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.mutedText,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.contentGap),
                    child,
                  ],
                ),
              ),
            );

            return SingleChildScrollView(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: isWide ? AppSpacing.pageVertical : 0,
                  ),
                  child: content,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class AuthHeroImage extends StatelessWidget {
  const AuthHeroImage({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.heroImage),
      child: Container(
        height: AppSizes.heroImageHeight,
        color: AppColors.heroBackground,
        child: Image.asset(
          'assets/images/howbuddy_mascot.jpg',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class AppTextField extends StatefulWidget {
  const AppTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.showPasswordToggle = false,
    this.validator,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool showPasswordToggle;
  final String? Function(String?)? validator;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _isObscured;

  @override
  void initState() {
    super.initState();
    _isObscured = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: _isObscured,
      validator: widget.validator,
      style: const TextStyle(
        color: AppColors.text,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(widget.icon, color: AppColors.primary),
        suffixIcon: widget.showPasswordToggle
            ? IconButton(
                onPressed: () => setState(() => _isObscured = !_isObscured),
                icon: Icon(
                  _isObscured ? Icons.visibility : Icons.visibility_off,
                  color: AppColors.mutedText,
                ),
              )
            : null,
      ),
    );
  }
}

class PasswordTipCard extends StatelessWidget {
  const PasswordTipCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.infoBackground,
        borderRadius: BorderRadius.circular(AppRadii.input),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.pageBackground,
            child: Icon(Icons.eco_rounded, color: AppColors.success),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Password must be at least 8 characters.',
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });

  final String text;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.primaryButtonHeight,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: AppSizes.loadingIndicator,
                height: AppSizes.loadingIndicator,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            : Stack(
                alignment: Alignment.center,
                children: [
                  Center(child: Text(text)),
                  const Positioned(
                    right: 20,
                    child: Icon(Icons.eco_rounded, color: AppColors.success),
                  ),
                ],
              ),
      ),
    );
  }
}

class SocialButton extends StatelessWidget {
  const SocialButton({
    required this.text,
    required this.icon,
    required this.onPressed,
    this.iconColor,
    this.isLoading = false,
    super.key,
  });

  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? iconColor;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.socialButtonHeight,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: AppSizes.socialLoadingIndicator,
                height: AppSizes.socialLoadingIndicator,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : Icon(icon, color: iconColor ?? AppColors.primary),
        label: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
        ),
      ),
    );
  }
}

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 22),
      child: Row(
        children: [
          Expanded(child: Divider()),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Text('or', style: TextStyle(color: AppColors.mutedText)),
          ),
          Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class AuthSwitchText extends StatelessWidget {
  const AuthSwitchText({
    required this.text,
    required this.linkText,
    required this.onPressed,
    super.key,
  });

  final String text;
  final String linkText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(text, style: const TextStyle(color: AppColors.mutedText)),
        ),
        TextButton(onPressed: onPressed, child: Text(linkText)),
      ],
    );
  }
}

String? _validateEmail(String? value) {
  final email = value?.trim() ?? '';
  final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  if (!emailPattern.hasMatch(email)) {
    return 'Enter a valid email address.';
  }
  return null;
}

String? _validatePassword(String? value) {
  if (value == null || value.length < 8) {
    return 'Password must be at least 8 characters.';
  }
  return null;
}
