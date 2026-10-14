import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app_style.dart';
import 'features/auth/auth_pages.dart';
import 'services/theme_preferences.dart';
import 'services/ui_translations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UiTranslations.loadSavedLanguage();
  if (!kIsWeb) {
    await MobileAds.instance.initialize();
  }
  final themePreferences = ThemePreferences();
  await themePreferences.load();
  runApp(HowBuddyApp(themePreferences: themePreferences));
}

class HowBuddyApp extends StatelessWidget {
  const HowBuddyApp({required this.themePreferences, super.key});

  final ThemePreferences themePreferences;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themePreferences,
      builder: (context, _) {
        AppColors.isDarkMode = themePreferences.isDarkMode;
        return ThemePreferencesScope(
          preferences: themePreferences,
          child: MaterialApp(
            title: 'HowBuddy',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themePreferences.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            home: const LoadingPage(),
          ),
        );
      },
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
    ThemePreferencesScope.watch(context);
    return Scaffold(
      backgroundColor: AppColors.loadingBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final logoWidth = (constraints.maxWidth * 0.88).clamp(0.0, 500.0);
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/images/how_buddy.svg',
                    width: logoWidth,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 38,
                    height: 38,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
