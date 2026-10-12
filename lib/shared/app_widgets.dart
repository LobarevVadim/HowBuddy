import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app_style.dart';
import '../services/theme_preferences.dart';

class TreePanel extends StatelessWidget {
  const TreePanel({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    ThemePreferencesScope.watch(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 620),
      decoration: BoxDecoration(
        color: AppColors.authPanelBackground,
        borderRadius: BorderRadius.circular(AppRadii.heroImage),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
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
    ThemePreferencesScope.watch(context);
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
    ThemePreferencesScope.watch(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.heroImage),
      child: Container(
        height: AppSizes.heroImageHeight,
        color: AppColors.heroBackground,
        child: SvgPicture.asset(
          'assets/images/how_buddy.svg',
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
    ThemePreferencesScope.watch(context);
    return TextFormField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: _isObscured,
      validator: widget.validator,
      style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
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
    ThemePreferencesScope.watch(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.infoBackground,
        borderRadius: BorderRadius.circular(AppRadii.input),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
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
    ThemePreferencesScope.watch(context);
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
                  Positioned(
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
    this.isEnabled = true,
    super.key,
  });

  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? iconColor;
  final bool isLoading;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    ThemePreferencesScope.watch(context);
    return SizedBox(
      height: AppSizes.socialButtonHeight,
      child: OutlinedButton.icon(
        onPressed: isLoading || !isEnabled ? null : onPressed,
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
          side: BorderSide(color: AppColors.border),
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
    ThemePreferencesScope.watch(context);
    return Padding(
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
    ThemePreferencesScope.watch(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(text, style: TextStyle(color: AppColors.mutedText)),
        ),
        TextButton(onPressed: onPressed, child: Text(linkText)),
      ],
    );
  }
}

String? validateEmailInput(String? value) {
  final email = value?.trim() ?? '';
  final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  if (!emailPattern.hasMatch(email)) {
    return 'Enter a valid email address.';
  }
  return null;
}

String? validatePasswordInput(String? value) {
  if (value == null || value.length < 8) {
    return 'Password must be at least 8 characters.';
  }
  return null;
}
