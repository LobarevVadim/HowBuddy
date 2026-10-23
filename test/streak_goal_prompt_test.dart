import 'package:flutter_test/flutter_test.dart';
import 'package:hello/features/gamification/streak_goal_page.dart';

void main() {
  test('an expired streak prompts for a new goal after its start day', () {
    expect(
      shouldPromptForStreakGoal(
        streakCount: 0,
        goalStartedAt: '2026-10-22',
        today: '2026-10-24',
      ),
      isTrue,
    );
  });

  test('a user with an active streak never sees the goal prompt', () {
    expect(
      shouldPromptForStreakGoal(
        streakCount: 1,
        goalStartedAt: '2026-10-22',
        today: '2026-10-24',
      ),
      isFalse,
    );
  });

  test(
    'restarting after choosing today does not prompt a second time that day',
    () {
      expect(
        shouldPromptForStreakGoal(
          streakCount: 0,
          goalStartedAt: '2026-10-24',
          today: '2026-10-24',
        ),
        isFalse,
      );
    },
  );

  test(
    'an inactive streak prompts again the following day if no lesson was done',
    () {
      expect(
        shouldPromptForStreakGoal(
          streakCount: 0,
          goalStartedAt: '2026-10-24',
          today: '2026-10-25',
        ),
        isTrue,
      );
    },
  );
}
