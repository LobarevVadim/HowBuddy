import bcrypt from 'bcryptjs';
import cors from 'cors';
import dotenv from 'dotenv';
import express from 'express';
import {OAuth2Client} from 'google-auth-library';
import pg from 'pg';
import {createHmac, timingSafeEqual} from 'node:crypto';
import {readFileSync} from 'node:fs';

dotenv.config();

const app = express();
const port = Number(process.env.PORT ?? 3000);
const sessionSecret = process.env.SESSION_SECRET ?? '';
const googleWebClientId = process.env.GOOGLE_WEB_CLIENT_ID ?? '';
const googleOAuthClient = new OAuth2Client();
const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
});
const lessonContent = JSON.parse(
  readFileSync(new URL('../data/lesson_exercises.json', import.meta.url), 'utf8'),
);

app.use(cors());
app.use(express.json());

app.get('/health', async (_request, response) => {
  try {
    await pool.query('SELECT 1');
    response.json({ok: true, database: 'connected'});
  } catch (_error) {
    response.status(503).json({ok: false, database: 'unavailable'});
  }
});

app.get('/onboarding/topics', (_request, response) => {
  response.json({topics: rootTopics()});
});

app.get('/gamification', requireAuth, async (request, response) => {
  const accountId = request.accountId;
  try {
    return response.json(await getGameState(accountId, clientStudyDate(request)));
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not load game progress.'});
  }
});

app.post('/gamification/lesson-start', requireAuth, async (request, response) => {
  const accountId = request.accountId;
  try {
    await ensureGameRow(accountId);
    const result = await pool.query(
      'UPDATE account_gamification SET hearts = hearts - 1 WHERE account_id = $1 AND hearts > 0 RETURNING hearts',
      [accountId],
    );
    return response.json({
      lessonAllowed: result.rowCount === 1,
      ...await getGameState(accountId, clientStudyDate(request)),
    });
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not use a lesson heart.'});
  }
});

app.post('/gamification/heart-video', requireAuth, async (request, response) => {
  const accountId = request.accountId;
  try {
    await ensureGameRow(accountId);
    await pool.query(
      'UPDATE account_gamification SET hearts = LEAST(5, hearts + 1) WHERE account_id = $1',
      [accountId],
    );
    return response.json(await getGameState(accountId, clientStudyDate(request)));
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not restore a heart.'});
  }
});

app.post('/gamification/emerald-video', requireAuth, async (request, response) => {
  const accountId = request.accountId;
  try {
    await ensureGameRow(accountId);
    await pool.query(
      'UPDATE account_gamification SET emeralds = emeralds + 25 WHERE account_id = $1',
      [accountId],
    );
    return response.json(await getGameState(accountId, clientStudyDate(request)));
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not add emeralds.'});
  }
});

app.post('/gamification/xp-boost', requireAuth, async (request, response) => {
  const accountId = request.accountId;
  const minutes = Number(request.body.durationMinutes);
  const price = new Map([[60, 80], [30, 45], [10, 20]]).get(minutes);
  if (!price) {
    return response.status(400).json({message: 'That XP boost is not available.'});
  }
  try {
    await ensureGameRow(accountId);
    const result = await pool.query(
      `UPDATE account_gamification
       SET emeralds = emeralds - $2,
           xp_boost_until = GREATEST(COALESCE(xp_boost_until, now()), now()) + ($3 * interval '1 minute')
       WHERE account_id = $1 AND emeralds >= $2
       RETURNING account_id`,
      [accountId, price, minutes],
    );
    if (result.rowCount !== 1) {
      return response.status(400).json({message: 'You do not have enough emeralds.'});
    }
    return response.json(await getGameState(accountId, clientStudyDate(request)));
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not buy the XP boost.'});
  }
});

app.post('/auth/register', async (request, response) => {
  const fullName = String(request.body.fullName ?? '').trim();
  const email = String(request.body.email ?? '').trim().toLowerCase();
  const password = String(request.body.password ?? '');

  if (fullName.length < 2 || !email.includes('@') || password.length < 8) {
    return response.status(400).json({message: 'Please complete all fields correctly.'});
  }

  const passwordHash = await bcrypt.hash(password, 12);

  try {
    const result = await pool.query(
      `INSERT INTO accounts (full_name, email, password_hash, auth_provider)
       VALUES ($1, $2, $3, 'password')
       RETURNING id, full_name, email`,
      [fullName, email, passwordHash],
    );

    return response.status(201).json({
      account: toAccount(result.rows[0]),
      sessionToken: issueSession(result.rows[0].id),
    });
  } catch (error) {
    if (error.code === '23505') {
      return response.status(409).json({message: 'An account already exists for this email.'});
    }

    console.error(error);
    return response.status(500).json({message: 'Could not create account.'});
  }
});

app.post('/auth/google', async (request, response) => {
  if (!googleWebClientId) {
    return response.status(503).json({message: 'Google sign-in is not configured on the server.'});
  }

  const idToken = String(request.body.idToken ?? '').trim();
  const allowRegistration = request.body.allowRegistration === true;
  if (!idToken || idToken.length > 10000) {
    return response.status(400).json({message: 'A valid Google sign-in token is required.'});
  }

  let googleUser;
  try {
    const ticket = await googleOAuthClient.verifyIdToken({
      idToken,
      audience: googleWebClientId,
    });
    googleUser = ticket.getPayload();
  } catch (_error) {
    return response.status(401).json({message: 'Google sign-in could not be verified.'});
  }
  if (!googleUser?.sub || !googleUser.email || googleUser.email_verified !== true) {
    return response.status(401).json({message: 'Google did not verify this email address.'});
  }

  try {
    const email = googleUser.email.toLowerCase();
    const existing = await pool.query(
      `SELECT id, full_name, email, provider_subject
       FROM accounts WHERE provider_subject = $1 OR email = $2 LIMIT 1`,
      [googleUser.sub, email],
    );

    let account = existing.rows[0];
    let isNewUser = false;
    if (account) {
      if (account.provider_subject && account.provider_subject !== googleUser.sub) {
        return response.status(409).json({message: 'This email is connected to a different sign-in method.'});
      }
      if (!account.provider_subject) {
        const linked = await pool.query(
          `UPDATE accounts SET provider_subject = $1
           WHERE id = $2 AND provider_subject IS NULL
           RETURNING id, full_name, email, provider_subject`,
          [googleUser.sub, account.id],
        );
        account = linked.rows[0] ?? account;
      }
    } else {
      if (!allowRegistration) {
        return response.status(404).json({message: 'No HowBuddy account uses this Google account. Sign up first.'});
      }
      const name = String(googleUser.name ?? '').trim() || email.split('@')[0];
      try {
        const created = await pool.query(
          `INSERT INTO accounts (full_name, email, auth_provider, provider_subject)
           VALUES ($1, $2, 'google', $3)
           RETURNING id, full_name, email, provider_subject`,
          [name, email, googleUser.sub],
        );
        account = created.rows[0];
        isNewUser = true;
      } catch (error) {
        if (error.code !== '23505') throw error;
        const raced = await pool.query(
          `SELECT id, full_name, email, provider_subject
           FROM accounts WHERE provider_subject = $1 OR email = $2 LIMIT 1`,
          [googleUser.sub, email],
        );
        account = raced.rows[0];
        if (!account || (account.provider_subject && account.provider_subject !== googleUser.sub)) {
          return response.status(409).json({message: 'An account already exists for this email.'});
        }
        if (!account.provider_subject) {
          const linked = await pool.query(
            `UPDATE accounts SET provider_subject = $1
             WHERE id = $2 AND provider_subject IS NULL
             RETURNING id, full_name, email, provider_subject`,
            [googleUser.sub, account.id],
          );
          account = linked.rows[0] ?? account;
        }
      }
    }

    return response.status(isNewUser ? 201 : 200).json({
      account: toAccount(account),
      sessionToken: issueSession(account.id),
      isNewUser,
    });
  } catch (error) {
    console.error('Google sign-in failed:', error.message);
    return response.status(500).json({message: 'Could not complete Google sign-in.'});
  }
});

app.get('/lessons/tree', requireAuth, async (request, response) => {
  const topic = findTopic(String(request.query.topic ?? lessonContent.roots[0]));
  if (!topic) return response.status(404).json({message: 'This lesson topic was not found.'});
  try {
    const levels = await buildLessonLevels(topic, request.accountId);
    return response.json({topic, levels, nextQuestions: getNextQuestions(topic.id)});
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not load lesson progress.'});
  }
});

app.get('/lessons/exercises', (request, response) => {
  const topicId = String(request.query.topic ?? '').trim();
  const lessonId = String(request.query.lesson ?? 'lesson-1').trim();
  const topicContent = lessonContent.nodes[topicId];
  if (!topicContent) {
    return response.status(404).json({message: 'No exercises are available for this topic.'});
  }
  const lessonNumber = Number(lessonId.replace('lesson-', ''));
  const extraNodeId = topicContent.extraLessons[lessonNumber - 2];
  const lesson = lessonNumber === 1 ? topicContent : lessonContent.nodes[extraNodeId];
  if (!lesson || !Number.isInteger(lessonNumber)) {
    return response.status(404).json({message: 'This lesson is not available.'});
  }
  return response.json({topic: topicId, content: lesson.content, exercises: lesson.exercises});
});

app.post('/lessons/complete', requireAuth, async (request, response) => {
  const topicId = String(request.body.topicId ?? '').trim();
  const lessonId = String(request.body.lessonId ?? '').trim();
  const accountId = request.accountId;
  const correctAnswers = Number(request.body.correctAnswers);
  const exerciseCount = Number(request.body.exerciseCount);
  const topic = findTopic(topicId);

  if (!topic) return response.status(404).json({message: 'This lesson topic was not found.'});
  if (!lessonId) {
    return response.status(400).json({message: 'Lesson is required.'});
  }
  if (
    !Number.isInteger(correctAnswers) ||
    !Number.isInteger(exerciseCount) ||
    exerciseCount < 1
  ) {
    return response.status(400).json({message: 'Lesson score is invalid.'});
  }

  const lessonNumber = Number(lessonId.replace('lesson-', ''));
  if (!Number.isInteger(lessonNumber) || lessonNumber < 1 || lessonNumber > topic.lessonCount) {
    return response.status(400).json({message: 'This lesson is not available.'});
  }

  const baseXp = 25 + Math.round(
    10 * Math.max(0, Math.min(correctAnswers, exerciseCount)) / exerciseCount,
  );

  try {
    await ensureGameRow(accountId);
    await pool.query(
      `INSERT INTO lesson_progress (account_id, topic_id, lesson_id)
       VALUES ($1, $2, $3) ON CONFLICT (account_id, topic_id, lesson_id) DO NOTHING`,
      [accountId, topic.id, lessonId],
    );
    const completionCount = await pool.query(
      'SELECT COUNT(*)::int AS count FROM lesson_progress WHERE account_id = $1 AND topic_id = $2',
      [accountId, topic.id],
    );
    const topicCompleted = completionCount.rows[0].count >= Math.min(topic.lessonCount, 20);
    await pool.query(
      'INSERT INTO study_days (account_id, study_date) VALUES ($1, $2::date) ON CONFLICT DO NOTHING',
      [accountId, clientStudyDate(request)],
    );
    const game = await pool.query(
      'SELECT xp_boost_until > now() AS boost_active FROM account_gamification WHERE account_id = $1',
      [accountId],
    );
    const earnedXp = baseXp * (game.rows[0].boost_active ? 2 : 1);
    const insertResult = await pool.query(
      `INSERT INTO lesson_xp (account_id, topic_id, lesson_id, xp)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (account_id, topic_id, lesson_id) DO NOTHING`,
      [accountId, topic.id, lessonId, earnedXp],
    );
    const awardedXp = insertResult.rowCount === 1 ? earnedXp : 0;
    const totals = await pool.query(
      'SELECT COALESCE(SUM(xp), 0)::int AS total_xp FROM lesson_xp WHERE account_id = $1',
      [accountId],
    );
    return response.json({
      ok: true,
      topicCompleted,
      earnedXp: awardedXp,
      totalXp: totals.rows[0].total_xp,
    });
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not save lesson progress.'});
  }
});

app.get('/xp/weekly', requireAuth, async (request, response) => {
  const accountId = request.accountId;

  try {
    const [totals, daily] = await Promise.all([
      pool.query(
        'SELECT COALESCE(SUM(xp), 0)::int AS total_xp FROM lesson_xp WHERE account_id = $1',
        [accountId],
      ),
      pool.query(
        `SELECT (created_at AT TIME ZONE 'UTC')::date::text AS date,
                SUM(xp)::int AS xp
         FROM lesson_xp
         WHERE account_id = $1
           AND created_at >= date_trunc('day', now() AT TIME ZONE 'UTC') - interval '6 days'
         GROUP BY (created_at AT TIME ZONE 'UTC')::date
         ORDER BY date`,
        [accountId],
      ),
    ]);
    const xpByDate = new Map(daily.rows.map((row) => [row.date, row.xp]));
    const today = new Date();
    const days = Array.from({length: 7}, (_item, index) => {
      const date = new Date(Date.UTC(
        today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate() - 6 + index,
      )).toISOString().slice(0, 10);
      return {date, xp: xpByDate.get(date) ?? 0};
    });
    return response.json({totalXp: totals.rows[0].total_xp, days});
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not load weekly XP.'});
  }
});

app.get('/notepad/tree', requireAuth, async (request, response) => {
  const accountId = request.accountId;
  try {
    return response.json({tree: await buildNotepadTree(accountId)});
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not load lesson progress.'});
  }
});

app.post('/auth/login', async (request, response) => {
  const identifier = String(request.body.identifier ?? '').trim().toLowerCase();
  const password = String(request.body.password ?? '');

  if (identifier.length === 0 || password.length < 8) {
    return response.status(400).json({message: 'Enter your login details.'});
  }

  const result = await pool.query(
    `SELECT id, full_name, email, password_hash
     FROM accounts
     WHERE email = $1 OR username = $1
     LIMIT 1`,
    [identifier],
  );

  const account = result.rows[0];
  if (!account || !account.password_hash || !(await bcrypt.compare(password, account.password_hash))) {
    return response.status(401).json({message: 'Invalid email, username, or password.'});
  }

  return response.json({
    account: toAccount(account),
    sessionToken: issueSession(account.id),
  });
});

function issueSession(accountId) {
  const header = encodeBase64Url(JSON.stringify({alg: 'HS256', typ: 'JWT'}));
  const payload = encodeBase64Url(JSON.stringify({
    sub: accountId,
    exp: Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60),
  }));
  const unsigned = `${header}.${payload}`;
  const signature = createHmac('sha256', sessionSecret).update(unsigned).digest('base64url');
  return `${unsigned}.${signature}`;
}

function encodeBase64Url(value) {
  return Buffer.from(value).toString('base64url');
}

function requireAuth(request, response, next) {
  const token = String(request.headers.authorization ?? '').replace(/^Bearer\s+/i, '');
  const parts = token.split('.');
  if (parts.length !== 3 || !sessionSecret) {
    return response.status(401).json({message: 'Please sign in again.'});
  }
  const unsigned = `${parts[0]}.${parts[1]}`;
  const expected = createHmac('sha256', sessionSecret).update(unsigned).digest();
  let actual;
  try {
    actual = Buffer.from(parts[2], 'base64url');
  } catch (_error) {
    return response.status(401).json({message: 'Your session is invalid. Please sign in again.'});
  }
  if (actual.length !== expected.length || !timingSafeEqual(actual, expected)) {
    return response.status(401).json({message: 'Your session is invalid. Please sign in again.'});
  }
  try {
    const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
    if (typeof payload.sub !== 'string' || payload.exp <= Date.now() / 1000) {
      return response.status(401).json({message: 'Your session expired. Please sign in again.'});
    }
    request.accountId = payload.sub;
    return next();
  } catch (_error) {
    return response.status(401).json({message: 'Your session is invalid. Please sign in again.'});
  }
}

function toAccount(row) {
  return {
    id: row.id,
    fullName: row.full_name,
    email: row.email,
  };
}

function findTopic(topicId) {
  const node = lessonContent.nodes[topicId];
  return node ? {id: node.id, question: node.question, lessonCount: node.lessonCount} : null;
}

function rootTopics() {
  return lessonContent.roots.map((id) => findTopic(id));
}

function getNextQuestions(topicId) {
  return (lessonContent.nodes[topicId]?.children ?? []).map((id) => ({
    id,
    question: lessonContent.nodes[id].question,
  }));
}

async function buildLessonLevels(topic, accountId) {
  const shapes = ['star', 'triangle', 'hexagon', 'square', 'circle'];
  const count = Math.min(topic.lessonCount, 20);
  const progress = accountId
    ? await pool.query(
        'SELECT lesson_id FROM lesson_progress WHERE account_id = $1 AND topic_id = $2',
        [accountId, topic.id],
      )
    : {rows: []};
  const lessonSet = new Set(progress.rows.map((row) => row.lesson_id));

  return Array.from({length: count}, (_item, index) => {
    const level = index + 1;
    const id = `lesson-${level}`;
    const previousId = `lesson-${level - 1}`;
    const isCompleted = lessonSet.has(id);
    const isUnlocked = level === 1 || lessonSet.has(previousId);

    return {
      id,
      level,
      shape: shapes[index % shapes.length],
      title: level === 1
        ? 'Core lesson'
        : lessonContent.nodes[
            lessonContent.nodes[topic.id].extraLessons[level - 2]
          ].question,
      isCompleted,
      isUnlocked,
    };
  });
}

async function buildNotepadTree(accountId) {
  const result = await pool.query(
    `SELECT topic_id, COUNT(*)::int AS count
     FROM lesson_progress WHERE account_id = $1 GROUP BY topic_id`,
    [accountId],
  );
  const completedTopics = new Set(
    result.rows
      .filter((row) => row.count >= Math.min(findTopic(row.topic_id)?.lessonCount ?? 20, 20))
      .map((row) => row.topic_id),
  );
  const buildNode = (id) => {
    const node = lessonContent.nodes[id];
    return {
      id,
      title: node.question,
      isCompleted: completedTopics.has(id),
      children: node.children.map(buildNode),
    };
  };
  return {
    id: 'main-tree',
    title: 'Main Tree',
    isCompleted: lessonContent.roots.every((id) => completedTopics.has(id)),
    children: lessonContent.roots.map(buildNode),
  };
}

async function ensureGameRow(accountId) {
  await pool.query(
    'INSERT INTO account_gamification (account_id) VALUES ($1) ON CONFLICT (account_id) DO NOTHING',
    [accountId],
  );
}

async function getGameState(accountId, today = new Date().toISOString().slice(0, 10)) {
  await ensureGameRow(accountId);
  await pool.query(
    'DELETE FROM study_days WHERE account_id = $1 AND study_date = $2::date + 1',
    [accountId, today],
  );
  const [result, studyResult] = await Promise.all([
    pool.query(
      'SELECT hearts, emeralds, xp_boost_until FROM account_gamification WHERE account_id = $1',
      [accountId],
    ),
    pool.query(
      'SELECT study_date::text AS day FROM study_days WHERE account_id = $1 ORDER BY study_date',
      [accountId],
    ),
  ]);
  const studyDays = studyResult.rows
    .map((row) => row.day)
    .filter((day) => day <= today);
  const studied = new Set(studyDays);
  let cursor = new Date(`${today}T00:00:00.000Z`);
  if (!studied.has(cursor.toISOString().slice(0, 10))) {
    cursor.setUTCDate(cursor.getUTCDate() - 1);
  }
  let streakCount = 0;
  while (studied.has(cursor.toISOString().slice(0, 10))) {
    streakCount++;
    cursor.setUTCDate(cursor.getUTCDate() - 1);
  }
  const game = result.rows[0];
  return {
    hearts: game.hearts,
    emeralds: game.emeralds,
    streakCount,
    studyDays,
    xpBoostUntil: game.xp_boost_until?.toISOString() ?? null,
  };
}

function clientStudyDate(request) {
  const candidate = request.get('X-Client-Date');
  if (!/^\d{4}-\d{2}-\d{2}$/.test(candidate ?? '')) {
    return new Date().toISOString().slice(0, 10);
  }
  const parsed = new Date(`${candidate}T00:00:00.000Z`);
  if (Number.isNaN(parsed.valueOf()) || parsed.toISOString().slice(0, 10) !== candidate) {
    return new Date().toISOString().slice(0, 10);
  }
  const utcToday = new Date().toISOString().slice(0, 10);
  const dayDelta = (parsed.valueOf() - new Date(`${utcToday}T00:00:00.000Z`).valueOf()) / 86400000;
  return Math.abs(dayDelta) <= 1 ? candidate : utcToday;
}

pool.query(readFileSync(new URL('../schema.sql', import.meta.url), 'utf8')).then(() => {
  if (sessionSecret.length < 32) {
    throw new Error('SESSION_SECRET must contain at least 32 characters.');
  }
  app.listen(port, () => {
    console.log(`HowBuddy auth API listening on http://localhost:${port}`);
  });
}).catch((error) => {
  console.error('Could not initialize the XP table.', error);
  process.exitCode = 1;
});
