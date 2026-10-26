import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static bool isDarkMode = false;

  static Color get primary =>
      isDarkMode ? const Color(0xFFE2A765) : const Color(0xFF995A2A);
  static Color get primaryDark =>
      isDarkMode ? const Color(0xFFFFD9B0) : const Color(0xFF6F482C);
  static Color get primaryLight =>
      isDarkMode ? const Color(0xFFD7A269) : const Color(0xFFA86B38);
  static Color get success =>
      isDarkMode ? const Color(0xFFB6D878) : const Color(0xFF617C2A);
  static Color get text =>
      isDarkMode ? const Color(0xFFF4E8DC) : const Color(0xFF65462F);
  static Color get mutedText =>
      isDarkMode ? const Color(0xFFC1AD98) : const Color(0xFF76614D);
  static Color get pageBackground =>
      isDarkMode ? const Color(0xFF1E1A17) : const Color(0xFFFFF8F2);
  static Color get loadingBackground =>
      isDarkMode ? const Color(0xFF1E1A17) : const Color(0xFFFCF5EF);
  static Color get inputBackground =>
      isDarkMode ? const Color(0xFF302923) : const Color(0xFFFFFCF8);
  static Color get border =>
      isDarkMode ? const Color(0xFF8B735B) : const Color(0xFFA58D74);
  static Color get authPanelBackground =>
      isDarkMode ? const Color(0xFF30261F) : const Color(0xFFFFF3E8);
  static Color get heroBackground =>
      isDarkMode ? const Color(0xFF29221C) : const Color(0xFFFFF8F2);
  static Color get infoBackground =>
      isDarkMode ? const Color(0xFF30271F) : const Color(0xFFFFF7EC);
  static const google = Color(0xFF4285F4);
  static const apple = Color(0xFF8B5CF6);
}

class AppFonts {
  const AppFonts._();

  static const primary = 'Arial';
}

class AppRadii {
  const AppRadii._();

  static const input = 18.0;
  static const button = 18.0;
  static const heroImage = 28.0;
}

class AppSpacing {
  const AppSpacing._();

  static const pageHorizontal = 24.0;
  static const pageHorizontalWide = 32.0;
  static const pageVertical = 28.0;
  static const fieldGap = 14.0;
  static const sectionGap = 22.0;
  static const titleGap = 8.0;
  static const heroGap = 26.0;
  static const contentGap = 28.0;
  static const authSwitchGap = 20.0;
  static const socialButtonGap = 12.0;
  static const homePadding = 28.0;
  static const homeIconGap = 16.0;
  static const homeTextGap = 8.0;
  static const homeButtonGap = 24.0;
  static const tabPagePadding = 28.0;
  static const tabIconGap = 16.0;
  static const tabTextGap = 8.0;
  static const profileLogoutGap = 24.0;
  static const passwordTipGap = 14.0;
}

class AppSizes {
  const AppSizes._();

  static const authContentMaxWidth = 460.0;
  static const wideLayoutBreakpoint = 780.0;
  static const primaryButtonHeight = 62.0;
  static const socialButtonHeight = 58.0;
  static const loadingIndicator = 22.0;
  static const socialLoadingIndicator = 20.0;
  static const heroMaxHeight = 310.0;
  static const heroImageHeight = 250.0;
  static const heroIconCircle = 150.0;
  static const heroIcon = 76.0;
  static const heroBubbleOne = 58.0;
  static const heroBubbleTwo = 76.0;
  static const successIcon = 68.0;
  static const tabHeroIcon = 64.0;
}

class AppPositions {
  const AppPositions._();

  static const heroBubbleOneLeft = 28.0;
  static const heroBubbleOneTop = 26.0;
  static const heroBubbleTwoRight = 34.0;
  static const heroBubbleTwoBottom = 28.0;
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.input),
      borderSide: BorderSide(color: AppColors.border),
    );

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
      ),
      scaffoldBackgroundColor: AppColors.pageBackground,
      fontFamily: AppFonts.primary,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBackground,
        labelStyle: TextStyle(
          color: AppColors.mutedText,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: AppColors.primary,
        suffixIconColor: AppColors.mutedText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 20,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primaryDark),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: brightness == Brightness.dark
              ? const Color(0xFF231F20)
              : Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.55),
          disabledForegroundColor: brightness == Brightness.dark
              ? const Color(0xFF231F20)
              : Colors.white,
        ),
      ),
    );
  }
}
