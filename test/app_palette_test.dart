import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello/app_style.dart';

void main() {
  test('theme construction follows its brightness independently of legacy global state', () {
    AppColors.isDarkMode = true;
    final light = AppTheme.light();
    AppColors.isDarkMode = false;
    final dark = AppTheme.dark();
    expect(light.scaffoldBackgroundColor, const AppPalette(Brightness.light).pageBackground);
    expect(dark.scaffoldBackgroundColor, const AppPalette(Brightness.dark).pageBackground);
    expect(light.scaffoldBackgroundColor, isNot(dark.scaffoldBackgroundColor));
  });
}
