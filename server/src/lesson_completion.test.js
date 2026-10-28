import test from 'node:test';
import assert from 'node:assert/strict';
import {createTestDatabase} from './test_database.js';
import {completeLesson, startLesson, lessonRevision} from './lesson_completion.js';

const lesson = {exercises: [{type: 'singleChoice', options: ['Cell', 'Rock'], correctAnswers: ['Cell']}]};
const databaseAvailable = Boolean(process.env.HOWBUDDY_TEST_DATABASE_URL);

test('completion is atomic, replays deterministically, grades trusted attempts and serializes concurrency', {skip: !databaseAvailable}, async (t) => {
  const pool = await createTestDatabase(t);
  const accountId = (await pool.query("INSERT INTO accounts(full_name,email) VALUES ('Test','test@invalid') RETURNING id")).rows[0].id;
  await pool.query('INSERT INTO account_gamification(account_id) VALUES ($1)', [accountId]);
  const input = {pool, accountId, topicId: 'cells', lessonId: 'lesson-1', lesson, lessonCount: 1, today: '2026-10-27', requestId: 'start-1'};
  const starts = await Promise.all(Array.from({length: 6}, () => startLesson(input)));
  starts.forEach((id) => assert.equal(id, starts[0]));
  input.completionId = starts[0];
  await assert.rejects(completeLesson(input), (error) => error.code === 'incomplete_attempts');
  await pool.query(`INSERT INTO lesson_session_attempts(session_id,exercise_index,student_answer,content_revision)
    VALUES($1,0,' cell ',$2)`, [input.completionId, lessonRevision(lesson)]);
  assert.equal(await startLesson(input), input.completionId);
  assert.equal((await pool.query('SELECT hearts FROM account_gamification WHERE account_id=$1', [accountId])).rows[0].hearts, 4);
  await assert.rejects(completeLesson({...input, afterProgress: () => { throw new Error('injected failure'); }}), /injected failure/);
  for (const table of ['lesson_progress', 'lesson_xp', 'study_days', 'lesson_completion_receipts']) {
    assert.equal((await pool.query(`SELECT count(*)::int AS count FROM ${table}`)).rows[0].count, 0, table);
  }
  const results = await Promise.all(Array.from({length: 6}, () => completeLesson(input)));
  results.forEach((result) => assert.deepEqual(result, results[0]));
  assert.equal(results[0].earnedXp, 5); // Stored incorrect flag and client score are not trusted.
  assert.equal((await pool.query('SELECT sum(xp)::int AS xp FROM lesson_xp')).rows[0].xp, 5);
  assert.deepEqual(await completeLesson({...input, today: '2026-10-28'}), results[0]);
  assert.equal((await pool.query('SELECT count(*)::int AS count FROM study_days')).rows[0].count, 1);
  const practiceId = await startLesson({...input, requestId: 'practice-2'});
  await pool.query('INSERT INTO lesson_session_attempts(session_id,exercise_index,student_answer,content_revision,answer_json) SELECT $1,exercise_index,student_answer,content_revision,answer_json FROM lesson_session_attempts WHERE session_id=$2', [practiceId, input.completionId]);
  const practice = await completeLesson({...input, today: '2026-10-28', completionId: practiceId});
  assert.equal(practice.earnedXp, 0);
  assert.equal((await pool.query('SELECT count(*)::int AS count FROM study_days')).rows[0].count, 2);
});

test('failure after each completion write rolls back XP, study day, freeze reward and receipt; server duration applies', {skip: !databaseAvailable}, async (t) => {
  const pool = await createTestDatabase(t);
  const accountId = (await pool.query("INSERT INTO accounts(full_name,email) VALUES ('Test','test@invalid') RETURNING id")).rows[0].id;
  const input = {pool, accountId, topicId: 'cells', lessonId: 'lesson-1', lesson, lessonCount: 1, today: '2026-10-27', requestId: 'start-1'};
  input.completionId = await startLesson(input);
  await pool.query("UPDATE lesson_sessions SET started_at=now()-interval '181 seconds' WHERE id=$1", [input.completionId]);
  await pool.query("UPDATE account_gamification SET streak_goal_days=7,streak_goal_started_at='2026-10-21' WHERE account_id=$1", [accountId]);
  await pool.query("INSERT INTO study_days SELECT $1,'2026-10-27'::date-n FROM generate_series(1,6) AS n", [accountId]);
  await pool.query("INSERT INTO lesson_session_attempts(session_id,exercise_index,student_answer,content_revision) VALUES($1,0,'Cell',$2)", [input.completionId, lessonRevision(lesson)]);
  for (const failAfter of ['INSERT INTO lesson_progress', 'INSERT INTO study_days', 'INSERT INTO lesson_xp', 'UPDATE account_gamification SET streak_freezes_remaining', 'INSERT INTO lesson_completion_receipts', 'UPDATE accounts SET last_active_at']) {
    const failingPool = {async connect() {
      const client = await pool.connect();
      return {async query(sql, values) {
        const result = await client.query(sql, values);
        if (sql.includes(failAfter)) throw new Error('injected write failure');
        return result;
      }, release: () => client.release()};
    }};
    await assert.rejects(completeLesson({...input, pool: failingPool}), /injected write failure/);
    for (const table of ['lesson_progress', 'lesson_xp', 'lesson_completion_receipts']) {
      assert.equal((await pool.query(`SELECT count(*)::int AS count FROM ${table}`)).rows[0].count, 0, failAfter);
    }
    assert.equal((await pool.query('SELECT count(*)::int AS count FROM study_days')).rows[0].count, 6);
    const game = (await pool.query('SELECT streak_goal_days,streak_freezes_remaining FROM account_gamification')).rows[0];
    assert.equal(game.streak_goal_days, 7);
    assert.equal(game.streak_freezes_remaining, 0);
  }
  const result = await completeLesson(input);
  assert.equal(result.earnedXp, 4);
  assert.equal(result.streakFreezesAwarded, 1);
  assert.deepEqual(await completeLesson(input), result);
});

test('stale content and locked lesson cannot award progress', {skip: !databaseAvailable}, async (t) => {
  const pool = await createTestDatabase(t);
  const accountId = (await pool.query("INSERT INTO accounts(full_name,email) VALUES ('Test','test@invalid') RETURNING id")).rows[0].id;
  const input = {pool, accountId, topicId: 'cells', lessonId: 'lesson-2', lesson, lessonCount: 2, today: '2026-10-27', requestId: 'start-1'};
  await assert.rejects(startLesson(input), (error) => error.code === 'lesson_locked');
  const completionId = await startLesson({...input, lessonId: 'lesson-1'});
  await assert.rejects(completeLesson({...input, lessonId: 'lesson-1', completionId}), (error) => error.code === 'incomplete_attempts');
  await pool.query(`INSERT INTO lesson_session_attempts(session_id,exercise_index,student_answer,content_revision)
    VALUES($1,0,'Cell','old-revision')`, [completionId]);
  await assert.rejects(completeLesson({...input, lessonId: 'lesson-1', completionId}), (error) => error.code === 'content_changed');
  await pool.query('UPDATE account_gamification SET hearts=0 WHERE account_id=$1', [accountId]);
  await assert.rejects(startLesson({...input, lessonId: 'lesson-1', requestId: 'no-hearts'}), (error) => error.code === 'no_hearts');
  await assert.rejects(completeLesson({...input, lessonId: 'lesson-1', completionId: '00000000-0000-0000-0000-000000000000'}), (error) => error.code === 'lesson_not_started');
});
