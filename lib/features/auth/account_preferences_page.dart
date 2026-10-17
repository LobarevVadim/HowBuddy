import 'package:flutter/material.dart';

import '../../app_style.dart';
import '../../models/app_models.dart';
import '../../services/auth_api.dart';
import '../../services/ui_translations.dart';
import '../../shared/app_widgets.dart';

typedef AccountPreferencesNextPage =
    Widget Function(BuildContext context, Account account);

class AccountLanguageOption {
  const AccountLanguageOption(this.code, this.name);

  final String code;
  final String name;
}

const accountLanguageOptions = [
  AccountLanguageOption('en', 'English'),
  AccountLanguageOption('fr', 'French'),
  AccountLanguageOption('es', 'Spanish'),
  AccountLanguageOption('hi', 'Hindi'),
  AccountLanguageOption('ru', 'Russian'),
];

class AccountPreferencesPage extends StatefulWidget {
  const AccountPreferencesPage({
    required this.account,
    required this.nextPageBuilder,
    super.key,
  });

  final Account account;
  final AccountPreferencesNextPage nextPageBuilder;

  @override
  State<AccountPreferencesPage> createState() => _AccountPreferencesPageState();
}

class _AccountPreferencesPageState extends State<AccountPreferencesPage> {
  late String _preferredLanguage =
      widget.account.preferredLanguage ?? accountLanguageOptions.first.code;
  late int _ageYears = widget.account.ageYears ?? 18;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    UiTranslations.saveLanguage(_preferredLanguage);
  }

  Future<void> _continue() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await AuthApi().saveAccountPreferences(
        preferredLanguage: _preferredLanguage,
        ageYears: _ageYears,
      );
      if (!mounted) return;
      final account = Account(
        id: widget.account.id,
        fullName: widget.account.fullName,
        email: widget.account.email,
        avatarPaletteIndex: widget.account.avatarPaletteIndex,
        glassesAccessoryIndex: widget.account.glassesAccessoryIndex,
        avatarEmoji: widget.account.avatarEmoji,
        preferredLanguage: _preferredLanguage,
        ageYears: _ageYears,
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => widget.nextPageBuilder(context, account),
        ),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      _showError(error.message);
    } catch (_) {
      if (!mounted) return;
      _showError(
        uiText(context, 'Could not save your preferences. Please try again.'),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(uiText(context, message))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.tabPagePadding),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthHeroImage(),
                  const SizedBox(height: AppSpacing.heroGap),
                  Text(
                    uiText(context, 'A couple of details'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    uiText(context, 'Choose your preferred language and age.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.mutedText),
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    initialValue: _preferredLanguage,
                    decoration: InputDecoration(
                      labelText: uiText(context, 'Language preference'),
                    ),
                    items: [
                      for (final language in accountLanguageOptions)
                        DropdownMenuItem(
                          value: language.code,
                          child: Text(
                            UiTranslations.languageName(language.code),
                          ),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value != null) {
                              UiTranslations.saveLanguage(value);
                              setState(() => _preferredLanguage = value);
                            }
                          },
                  ),
                  const SizedBox(height: AppSpacing.fieldGap),
                  DropdownButtonFormField<int>(
                    initialValue: _ageYears,
                    decoration: InputDecoration(
                      labelText: uiText(context, 'Age'),
                    ),
                    items: [
                      for (var age = 1; age <= 120; age++)
                        DropdownMenuItem(value: age, child: Text('$age')),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _ageYears = value);
                            }
                          },
                  ),
                  const SizedBox(height: AppSpacing.sectionGap),
                  PrimaryButton(
                    text: uiText(context, 'Continue'),
                    isLoading: _saving,
                    onPressed: _continue,
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
