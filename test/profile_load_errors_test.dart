import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello/features/home/home_page.dart';
import 'package:hello/features/profile/notification_preferences_panel.dart';
import 'package:hello/models/app_models.dart';
import 'package:hello/services/notification_service.dart';
import 'package:hello/services/theme_preferences.dart';
import 'package:hello/services/ui_translations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'notification preferences distinguish pending, failure, retry and loaded states',
    (tester) async {
      UiTranslations.setLanguage('en');
      final pending = Completer<NotificationPreferences>();
      var requests = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationPreferencesPanel(
              accountId: 'test',
              loadPreferences: () {
                requests++;
                if (requests == 1) return pending.future;
                return Future.value(
                  const NotificationPreferences(
                    enabled: false,
                    curiosityEnabled: true,
                    quietHoursEnabled: true,
                    quietStartMinute: 1320,
                    quietEndMinute: 480,
                  ),
                );
              },
            ),
          ),
        ),
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      pending.completeError(StateError('offline'));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(
        find.text('Could not load notification preferences.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(requests, 2);
      expect(find.byType(SwitchListTile), findsWidgets);
      expect(find.text('Retry'), findsNothing);
    },
  );

  testWidgets(
    'Home game progress failure offers a retry that recovers balances',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      UiTranslations.setLanguage('en');
      final pending = Completer<GameState>();
      var requests = 0;
      final theme = ThemePreferences();
      addTearDown(theme.dispose);
      await tester.pumpWidget(
        ThemePreferencesScope(
          preferences: theme,
          child: MaterialApp(
            home: HomePage(
              account: const Account(
                id: 'test',
                fullName: 'Test',
                email: 'test@example.invalid',
              ),
              initialIndex: 3,
              onLogout: () {},
              loadGameState: (_) {
                requests++;
                if (requests == 1) return pending.future;
                return Future.value(
                  GameState.fromJson({'hearts': 4, 'emeralds': 75}),
                );
              },
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('game-state-loading')), findsOneWidget);
      pending.completeError(StateError('offline'));
      await tester.pump();
      expect(find.byKey(const ValueKey('game-state-loading')), findsNothing);
      expect(find.byKey(const ValueKey('retry-game-state')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('retry-game-state')));
      await tester.pump();
      await tester.pump();
      expect(requests, 2);
      expect(find.byKey(const ValueKey('retry-game-state')), findsNothing);
      expect(find.text('75'), findsOneWidget);
    },
  );
}
