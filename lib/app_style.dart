import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const primary = Color(0xFF2563EB);
  static const success = Color(0xFF16A34A);
  static const text = Color(0xFF0F172A);
  static const mutedText = Color(0xFF64748B);
  static const pageBackground = Colors.white;
  static const inputBackground = Color(0xFFF8FAFC);
  static const border = Color(0xFFE2E8F0);
  static const authPanelBackground = Color(0xFFEFF6FF);
  static const heroBackground = Color(0xFFDBEAFE);
  static const heroBubbleOne = Color(0xFFBFDBFE);
  static const heroBubbleTwo = Color(0xFFBAE6FD);
}

class AppFonts {
  const AppFonts._();

  static const primary = 'Arial';
}

class AppRadii {
  const AppRadii._();

  static const input = 14.0;
  static const button = 14.0;
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
}

class AppSizes {
  const AppSizes._();

  static const authContentMaxWidth = 460.0;
  static const wideLayoutBreakpoint = 780.0;
  static const primaryButtonHeight = 54.0;
  static const socialButtonHeight = 52.0;
  static const loadingIndicator = 22.0;
  static const socialLoadingIndicator = 20.0;
  static const heroMaxHeight = 320.0;
  static const heroIconCircle = 150.0;
  static const heroIcon = 76.0;
  static const heroBubbleOne = 58.0;
  static const heroBubbleTwo = 76.0;
  static const successIcon = 68.0;
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

  static ThemeData light() {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.input),
      borderSide: const BorderSide(color: AppColors.border),
    );

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),
      fontFamily: AppFonts.primary,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBackground,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
