import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello/features/learning/lesson_session_controller.dart';
import 'package:hello/features/learning/lesson_exercises.dart';
import 'package:hello/models/app_models.dart';

LessonContent content() => LessonContent(
  content: 'Cells',
  exercises: [
    LessonExercise.fromJson({
      'type': 'singleChoice',
      'prompt': 'Living?',
      'options': ['Cell', 'Rock'],
      'correctAnswers': ['Cell'],
      'explanation': 'Cells live.',
    }),
  ],
);

void main() {
  test(
    'content and optional tutor status load independently; retry clears error',
    () async {
      var loads = 0;
      final controller = LessonSessionController(
        loadContent: () async {
          if (++loads == 1) throw Exception('offline');
          return content();
        },
        loadAttempts: () async => throw Exception('tutor offline'),
        recordAttempt: (_, _) async => true,
        complete: (_, _, _) async => throw UnimplementedError(),
      );
      addTearDown(controller.dispose);
      expect(await controller.load(), isFalse);
      expect(controller.loadError, isNotNull);
      expect(await controller.load(), isTrue);
      expect(controller.loadError, isNull);
      expect(controller.lesson!.exercises.length, 1);
      expect(controller.attemptedResults, isEmpty);
    },
  );

  test(
    'submission failure is retryable and duplicate checks cannot inflate score',
    () async {
      var submissions = 0;
      final controller = LessonSessionController(
        loadContent: () async => content(),
        loadAttempts: () async => {},
        recordAttempt: (_, _) async {
          if (++submissions == 1) throw Exception('offline');
          return false;
        },
        complete: (_, _, _) async => throw UnimplementedError(),
      );
      addTearDown(controller.dispose);
      await controller.load();
      await expectLater(controller.submit(0, 'Rock'), throwsException);
      expect(controller.isChecking, isFalse);
      expect(controller.correctCount, 0);
      expect(await controller.submit(0, 'Rock'), isFalse);
      expect(await controller.submit(0, 'Cell'), isFalse);
      expect(submissions, 2);
      expect(controller.correctCount, 0);
    },
  );

  test(
    'finish retries with same session and coalesces callers; disposal ignores late reads',
    () async {
      var completions = 0;
      final save = Completer<LessonCompletion>();
      final controller = LessonSessionController(
        loadContent: () async => content(),
        loadAttempts: () async => {},
        recordAttempt: (_, _) async => true,
        complete: (correct, total, duration) {
          completions++;
          expect(correct, 1);
          expect(total, 1);
          return save.future;
        },
      );
      await controller.load();
      await controller.submit(0, 'Cell');
      final first = controller.finish();
      final second = controller.finish();
      save.complete(
        const LessonCompletion(
          earnedXp: 5,
          totalXp: 5,
          topicCompleted: true,
          streakFreezesAwarded: 0,
        ),
      );
      expect((await first)!.earnedXp, 5);
      expect(await second, same(controller.completion));
      await controller.finish();
      expect(completions, 1);
      controller.dispose();

      final pending = Completer<LessonContent>();
      final late = LessonSessionController(
        loadContent: () => pending.future,
        loadAttempts: () async => {},
        recordAttempt: (_, _) async => true,
        complete: (_, _, _) async => throw UnimplementedError(),
      );
      final load = late.load();
      late.dispose();
      pending.complete(content());
      expect(await load, isFalse);
      expect(late.lesson, isNull);
    },
  );
}
