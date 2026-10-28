import {gradeAnswer, gradeResponse} from './exercise_grading.js';
import {lessonRevision} from './content_revision.js';
import {countStreakThroughToday} from './streak_freeze_policy.js';
export {lessonRevision} from './content_revision.js';

export class CompletionError extends Error {
  constructor(code, message, status = 409) {
    super(message);
    this.code = code;
    this.status = status;
  }
}

async function lockContentGeneration(client, generation) {
  if (generation == null) return;
  const current = (await client.query('SELECT generation::text AS generation FROM content_generation WHERE singleton FOR SHARE')).rows[0]?.generation;
  if (current !== String(generation)) throw new CompletionError('content_changed', 'This lesson has changed. Please reopen it and answer again.');
}

export async function startLesson({pool, accountId, topicId, lessonId, lesson, lessonCount, requestId, generation}) {
  if (typeof requestId !== 'string' || !/^[a-zA-Z0-9_-]{1,160}$/.test(requestId)) {
    throw new CompletionError('invalid_start_id', 'Please reopen this lesson.', 400);
  }
  const number = Number(/^lesson-([1-9]\d?)$/.exec(lessonId)?.[1]);
  if (!number || number > Math.min(lessonCount, 20) || !lesson?.exercises?.length) {
    throw new CompletionError('invalid_lesson', 'This lesson is not available.', 400);
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await lockContentGeneration(client, generation);
    await client.query('INSERT INTO account_gamification(account_id) VALUES ($1) ON CONFLICT DO NOTHING', [accountId]);
    await client.query('SELECT account_id FROM account_gamification WHERE account_id=$1 FOR UPDATE', [accountId]);
    const replay = await client.query('SELECT id,topic_id,lesson_id FROM lesson_sessions WHERE account_id=$1 AND start_key=$2', [accountId, requestId]);
    if (replay.rowCount) {
      if (replay.rows[0].topic_id !== topicId || replay.rows[0].lesson_id !== lessonId) throw new CompletionError('start_id_conflict', 'Please reopen this lesson.');
      await client.query('COMMIT');
      return replay.rows[0].id;
    }
    if (number > 1 && !(await client.query('SELECT 1 FROM lesson_progress WHERE account_id=$1 AND topic_id=$2 AND lesson_id=$3', [accountId, topicId, `lesson-${number - 1}`])).rowCount) {
      throw new CompletionError('lesson_locked', 'Complete the previous lesson first.');
    }
    const heart = await client.query(`UPDATE account_gamification SET hearts=hearts-1,
      heart_recharge_at=COALESCE(heart_recharge_at, now()+interval '3 hours')
      WHERE account_id=$1 AND hearts>0 RETURNING hearts`, [accountId]);
    if (!heart.rowCount) throw new CompletionError('no_hearts', 'You need a heart to start a lesson.');
    const result = await client.query(`INSERT INTO lesson_sessions(account_id,topic_id,lesson_id,content_revision,start_key)
      VALUES($1,$2,$3,$4,$5) RETURNING id`, [accountId, topicId, lessonId, lessonRevision(lesson), requestId]);
    await client.query('COMMIT');
    return result.rows[0].id;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally { client.release(); }
}

export async function completeLesson({pool, accountId, topicId, lessonId, lesson, lessonCount, today,
  completionId, afterProgress, generation}) {
  if (typeof completionId !== 'string' || !/^[a-f0-9-]{36}$/i.test(completionId)) {
    throw new CompletionError('invalid_completion_id', 'Please reopen this lesson.', 400);
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await lockContentGeneration(client, generation);
    await client.query('INSERT INTO account_gamification(account_id) VALUES ($1) ON CONFLICT DO NOTHING', [accountId]);
    // Consistent per-account lock order, also used by freeze maintenance.
    const game = (await client.query('SELECT *, xp_boost_until > now() AS boost_active FROM account_gamification WHERE account_id = $1 FOR UPDATE', [accountId])).rows[0];
    const receipt = await client.query('SELECT result FROM lesson_completion_receipts WHERE account_id=$1 AND topic_id=$2 AND lesson_id=$3 AND completion_id=$4', [accountId, topicId, lessonId, completionId]);
    if (receipt.rowCount) {
      await client.query('COMMIT');
      return receipt.rows[0].result;
    }
    const session = (await client.query(`SELECT *, EXTRACT(EPOCH FROM (now()-started_at))::int AS duration
      FROM lesson_sessions WHERE id=$1 AND account_id=$2 AND topic_id=$3 AND lesson_id=$4`, [completionId, accountId, topicId, lessonId])).rows[0];
    if (!session) throw new CompletionError('lesson_not_started', 'Please start this lesson again.');
    const number = /^lesson-([1-9]\d?)$/.exec(lessonId)?.[1];
    if (!number || Number(number) > Math.min(lessonCount, 20) || !lesson?.exercises?.length) {
      throw new CompletionError('invalid_lesson', 'This lesson is not available.', 400);
    }
    if (session.content_revision !== lessonRevision(lesson)) throw new CompletionError('content_changed', 'This lesson has changed. Please reopen it and answer again.');
    const prior = await client.query('SELECT lesson_id FROM lesson_progress WHERE account_id=$1 AND topic_id=$2', [accountId, topicId]);
    const completed = new Set(prior.rows.map((row) => row.lesson_id));
    if (Number(number) > 1 && !completed.has(`lesson-${Number(number) - 1}`)) {
      throw new CompletionError('lesson_locked', 'Complete the previous lesson first.');
    }
    const historicalXp = await client.query('SELECT xp FROM lesson_xp WHERE account_id=$1 AND topic_id=$2 AND lesson_id=$3', [accountId, topicId, lessonId]);
    let earnedXp = 0;
    {
      const attempts = await client.query(`SELECT exercise_index, student_answer, content_revision, session_id, answer_json
        FROM lesson_session_attempts WHERE session_id=$1`, [completionId]);
      const byIndex = new Map(attempts.rows.map((row) => [row.exercise_index, row]));
      const revision = lessonRevision(lesson);
      let correctCount = 0;
      for (const [index, exercise] of lesson.exercises.entries()) {
        const attempt = byIndex.get(index);
        if (!attempt || attempt.session_id !== completionId) throw new CompletionError('incomplete_attempts', 'Answer each exercise before finishing.');
        if (attempt.content_revision !== revision) throw new CompletionError('content_changed', 'This lesson has changed. Please reopen it and answer again.');
        const grade = attempt.answer_json == null ? gradeAnswer(exercise, attempt.student_answer) : gradeResponse(exercise, attempt.answer_json);
        if (!grade.submitted) throw new CompletionError('incomplete_attempts', 'Answer each exercise before finishing.');
        if (grade.correct === true) correctCount++;
      }
      earnedXp = historicalXp.rowCount ? 0 : Math.round((correctCount * 5 + (lesson.exercises.length - correctCount) * 2) * (session.duration > 180 ? 0.8 : 1) * (game.boost_active ? 2 : 1));
    }
    await client.query('INSERT INTO lesson_progress(account_id,topic_id,lesson_id) VALUES($1,$2,$3) ON CONFLICT DO NOTHING', [accountId, topicId, lessonId]);
    if (afterProgress) await afterProgress(); // Failure injection seam; never supplied by HTTP input.
    // A genuine practice session counts as study; a receipt replay above does not.
    await client.query('INSERT INTO study_days(account_id,study_date) VALUES($1,$2::date) ON CONFLICT DO NOTHING', [accountId, today]);
    if (!historicalXp.rowCount) {
      await client.query('INSERT INTO lesson_xp(account_id,topic_id,lesson_id,xp) VALUES($1,$2,$3,$4)', [accountId, topicId, lessonId, earnedXp]);
    }
    const study = await client.query('SELECT study_date::text AS day FROM study_days WHERE account_id=$1', [accountId]);
    const frozen = await client.query('SELECT frozen_date::text AS day FROM streak_freeze_calendar_days WHERE account_id=$1', [accountId]);
    const streak = countStreakThroughToday({today, studyDays: study.rows.map((row) => row.day), frozenDays: frozen.rows.map((row) => row.day)});
    const award = streak === game.streak_goal_days ? new Map([[7, 1], [14, 3], [30, 7]]).get(game.streak_goal_days) ?? 0 : 0;
    if (award) {
      await client.query(`UPDATE account_gamification SET streak_freezes_remaining=streak_freezes_remaining+$2,
        streak_goal_days=NULL, streak_goal_started_at=NULL WHERE account_id=$1`, [accountId, award]);
    }
    completed.add(lessonId);
    const totalXp = (await client.query('SELECT COALESCE(sum(xp),0)::int AS total FROM lesson_xp WHERE account_id=$1', [accountId])).rows[0].total;
    const result = {ok: true, topicCompleted: completed.size >= Math.min(lessonCount, 20), earnedXp, totalXp,
      streakFreezesAwarded: award, streakFreezesRemaining: game.streak_freezes_remaining + award};
    await client.query('INSERT INTO lesson_completion_receipts(account_id,topic_id,lesson_id,completion_id,result) VALUES($1,$2,$3,$4,$5::jsonb)', [accountId, topicId, lessonId, completionId, JSON.stringify(result)]);
    await client.query('UPDATE accounts SET last_active_at=now() WHERE id=$1', [accountId]);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}
