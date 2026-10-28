# Refactor migration and compatibility notes

No production migration or deployment has been executed as part of this refactor.

## Apply and validate

1. Back up the intended database and verify restore access before an authorized rollout. Use a staging clone to check baseline `accounts`, `account_gamification`, `bobo_exercise_tutoring_state` and normalized content tables first. Existing installations must already have the pre-refactor schema; this runner does not replay historical schema repairs.
2. Run `npm ci --ignore-scripts` and `npm run migrate` with an explicitly selected `DATABASE_URL`. Migration CLI reads `.env`; tests never do. The runner serializes migrations with a transaction advisory lock and records applied versions in `schema_migrations`. Fresh databases bootstrap CREATE statements; historical content DROP jobs are deliberately excluded.
3. Migration 001 adds sessions, per-session answers, nullable tutor-projection fields and deterministic completion receipts. Migration 002 adds a singleton content-generation counter and transactional statement triggers on the six normalized content tables. No existing XP, progress, study history or lesson content is backfilled/deleted. Additive DDL still takes PostgreSQL locks: assess lock timeouts/table size on staging before rollout.
4. Start the API and verify health, authentication, lesson start/answer/completion, replay, and published content. Startup checks the generation table and loads content; it does not migrate, seed or repair data. `SEED_DEMO_USERS=true` and `RUN_STUDY_HISTORY_BACKFILL=true` are opt-ins for legacy utilities, not production defaults. Do not enable historical repair as a routine deployment option.

## Coordinated API/client contract

This is a coordinated upgrade, not backward-compatible completion behavior. Old learner clients do not send a session ID and cannot finish on the tightened API. New clients require `/lessons/start`, absent on the old API. Use a maintenance/coordinated release or an explicit old-client upgrade gate; do not silently mix versions.

`POST /lessons/start` receives `topicId`, `lessonId`, `requestId`. A client retains the requestId across failed retries of the same launch. The API atomically validates prerequisites, consumes one heart and creates a session; replay returns the same session. The Flutter launch state retains this key until the successful lesson route returns. Restarting the entire app before receiving a start response does not retain this key; durable cross-restart launch recovery remains a limitation.

`POST /bobo/attempts` adds `sessionId` and returns `correct`. The server verifies session ownership, stores each session's answers independently, and updates the existing latest-tutoring-state projection in the same transaction. Legacy tutor calls without sessionId can still use tutoring; they do not supply completion evidence.

`POST /lessons/complete` uses `completionId` equal to the server session UUID. Posted score/count/duration remain tolerated for old request shapes but are ignored for rewards. Server answers determine score; server start time determines the existing >180-second multiplier. One lifetime XP award per account/topic/lesson is retained. A new practice session records today's study day and can finish a streak goal, but earns no duplicate XP. Replaying a completion returns its original receipt, even if content has since disappeared, and creates no new study day.

Study dates use server time in a valid IANA client timezone (bounded UTC offset fallback). `X-Client-Date` is no longer authoritative. Existing dates are preserved; no guess-based historical correction is performed. A content edit invalidates a session whose exercise hash changed; the learner must reopen/reanswer. No automatic heart refund for administrative content edits is implemented.

## Recovery / rollback

These files are new, undeployed migrations and can still be revised during this working-tree batch. After first deployment, treat applied versions as immutable and use a new forward migration for changes.

For application rollback, stop the new API, restore the prior API/client together, and leave the additive tables/columns/triggers in place. Older code does not reference them. Do not drop session/receipt data during rollback. Review a forward recovery migration if a deployed version fails; restore a backup only through an explicitly authorized operational procedure. Do not rerun old automatic history-repair code as a rollback step.

## Isolated regression database

`npm test` discovers new Node tests automatically. DB tests require `HOWBUDDY_TEST_DATABASE_URL` with loopback host, database `howbuddy_test`, and role `howbuddy_test`; they never fall back to `DATABASE_URL` or load `.env`. Each test creates/drops only its own randomly named schema. CI provisions a disposable PostgreSQL 18 service. Without this variable, DB tests explicitly skip; a skipped suite is not transaction verification.
