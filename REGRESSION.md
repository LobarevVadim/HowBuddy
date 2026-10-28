# Module regression commands

Working backlog and current evidence: [REFACTOR_PLAN.md](REFACTOR_PLAN.md).

| Changed module | Dependency evidence / downstream consumers | Acceptance and propagation |
| --- | --- | --- |
| Server completion, sessions, migrations, content cache | `rg -n 'completeLesson\|startLesson\|getLessonSnapshot' server/src/app.js`; consumed by learner AuthApi/BoboTutorApi/lesson tree/page | `npm test` in server with isolated `HOWBUDDY_TEST_DATABASE_URL`; then root `flutter analyze`, `flutter test`, learner web release build after contract changes. |
| Flutter HTTP/session/ownership services | `rg -n 'ApiSession\|ApiTransport\|LatestRequest' lib`; consumed by auth, game state, tutor and notifications | Root `flutter analyze` and `flutter test`; real FCM, ads and account-switch device checks remain manual. |
| Presentation / shared theme | `rg -n 'AppTheme\|AppPalette\|BoboChatPanel\|XpTabPage' lib test tool` | Root analyzer/tests; `test/learning_visual_test.dart` generates narrow light/dark/large-text render artifacts. For review use real font environment variables documented in the plan. Browser/device keyboard and assistive technology are additional gates. |
| Support-admin braces | Mechanical-only change in two widgets; root analyzer includes these sources | Root `flutter analyze`; independent support-admin build is not established by learner tests. |

For externally observable API changes, run both server and Flutter checks. For internal-only styling/extraction, server rerun can be omitted if no contract/state dependency changed. Baseline before refactor: 73 server tests, 6 Flutter tests passed; analyzer had 9 pre-existing style infos. No commits were created; current work is compared to the starting working tree/HEAD plus untracked files, not a new commit checkpoint.
