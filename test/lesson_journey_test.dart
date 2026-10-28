import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello/features/learning/lesson_page.dart';
import 'package:hello/features/learning/lesson_exercises.dart';
import 'package:hello/features/learning/lesson_session_controller.dart';
import 'package:hello/models/app_models.dart';

void main() {
  testWidgets(
    'lesson loads, checks server answer, advances, retries save and shows authoritative XP',
    (tester) async {
      var saves = 0;
      final controller = LessonSessionController(
        loadContent: () async => LessonContent(
          content: 'Cells use energy.',
          exercises: [
            LessonExercise.fromJson({
              'type': 'singleChoice',
              'prompt': 'Which is alive?',
              'options': ['Cell', 'Rock'],
              'correctAnswers': ['Cell'],
              'explanation': 'Cells are living units.',
            }),
          ],
        ),
        loadAttempts: () async => {},
        recordAttempt: (index, answer) async {
          expect(index, 0);
          expect(answer, 'Cell');
          return true;
        },
        complete: (_, _, _) async {
          if (++saves == 1) throw AuthException('Could not save.');
          return const LessonCompletion(
            topicCompleted: true,
            earnedXp: 10,
            totalXp: 10,
          );
        },
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: LessonPage(
            controller: controller,
            sessionId: 'test-session',
            accountId: 'test-account',
            topicId: 'cells',
            level: const LessonLevel(
              id: 'lesson-1',
              level: 1,
              shape: 'star',
              title: 'Cells',
              isCompleted: false,
              isUnlocked: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cell'));
      await tester.pump();
      await tester.ensureVisible(find.text('Check answer'));
      await tester.tap(find.text('Check answer'));
      await tester.pumpAndSettle();
      expect(find.text('Correct!'), findsOneWidget);
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('1 / 1'), findsOneWidget);
      expect(find.text('XP estimate (without potion)'), findsNothing);
      await tester.ensureVisible(find.text('Finish lesson'));
      await tester.tap(find.text('Finish lesson'));
      await tester.pumpAndSettle();
      expect(find.text('Could not save.'), findsOneWidget);
      expect(find.text('Finish lesson'), findsOneWidget);
      await tester.tap(find.text('Finish lesson'));
      await tester.pumpAndSettle();
      expect(saves, 2);
      expect(find.text('10 XP'), findsOneWidget);
      expect(find.text('Back to lessons'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
