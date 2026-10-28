import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello/features/home/home_page.dart';
import 'package:hello/models/app_models.dart';
import 'package:hello/services/theme_preferences.dart';
import 'package:hello/services/ui_translations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'failed language save rolls Home and persisted language back after leaving Profile',
    (tester) async {
      SharedPreferences.setMockInitialValues({'howbuddy_ui_language': 'en'});
      UiTranslations.setLanguage('en');
      final pending = Completer<void>();
      final writes = <String>[];
      final theme = ThemePreferences();
      addTearDown(theme.dispose);
      await tester.pumpWidget(
        ThemePreferencesScope(
          preferences: theme,
          child: MaterialApp(
            home: HomePage(
              account: const Account(
                id: 'test-account',
                fullName: 'Test',
                email: 'test@example.invalid',
                preferredLanguage: 'en',
                ageYears: 18,
              ),
              initialIndex: 3,
              onLogout: () {},
              savePreferences: (language, age) {
                writes.add(language);
                return pending.future;
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is DropdownButtonFormField<String>,
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.text(UiTranslations.languageName('fr')).last);
      await tester.pump();
      expect(writes, ['fr']);
      expect(UiTranslations.languageCode, 'fr');
      expect(
        (await SharedPreferences.getInstance()).getString(
          'howbuddy_ui_language',
        ),
        'fr',
      );
      await tester.tap(find.byIcon(Icons.park_outlined));
      await tester.pump();
      expect(find.byType(ProfileTabPage), findsNothing);
      pending.completeError(StateError('offline'));
      await tester.pump();
      await tester.pump();
      expect(UiTranslations.languageCode, 'en');
      expect(
        (await SharedPreferences.getInstance()).getString(
          'howbuddy_ui_language',
        ),
        'en',
      );
      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pump(const Duration(milliseconds: 350));
      final languageField = tester.widget<DropdownButtonFormField<String>>(
        find.byWidgetPredicate(
          (widget) => widget is DropdownButtonFormField<String>,
        ),
      );
      expect(languageField.initialValue, 'en');
      expect(writes, ['fr']);
    },
  );
}
