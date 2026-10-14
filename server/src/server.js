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
    await refreshHearts(accountId);
    const result = await pool.query(
      `UPDATE account_gamification
       SET hearts = hearts - 1,
           heart_recharge_at = CASE
             WHEN hearts = 5 THEN now() + interval '3 hours'
             ELSE COALESCE(heart_recharge_at, now() + interval '3 hours')
           END
       WHERE account_id = $1 AND hearts > 0 RETURNING hearts`,
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
    await refreshHearts(accountId);
    await pool.query(
      `UPDATE account_gamification
       SET hearts = LEAST(5, hearts + 1),
           heart_recharge_at = CASE
             WHEN hearts + 1 >= 5 THEN NULL
             ELSE COALESCE(heart_recharge_at, now() + interval '3 hours')
           END
       WHERE account_id = $1`,
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
       RETURNING id, full_name, email, avatar_palette_index, preferred_language, age_years`,
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
      `SELECT id, full_name, email, provider_subject, avatar_palette_index,
              preferred_language, age_years
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
           RETURNING id, full_name, email, provider_subject, avatar_palette_index,
                     preferred_language, age_years`,
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
           RETURNING id, full_name, email, provider_subject, avatar_palette_index,
                     preferred_language, age_years`,
          [name, email, googleUser.sub],
        );
        account = created.rows[0];
        isNewUser = true;
      } catch (error) {
        if (error.code !== '23505') throw error;
        const raced = await pool.query(
          `SELECT id, full_name, email, provider_subject, avatar_palette_index,
                  preferred_language, age_years
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
             RETURNING id, full_name, email, provider_subject, avatar_palette_index,
                       preferred_language, age_years`,
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

app.get('/account/last-topic', requireAuth, async (request, response) => {
  try {
    const result = await pool.query(
      'SELECT last_topic_id FROM accounts WHERE id = $1',
      [request.accountId],
    );
    return response.json({topicId: result.rows[0]?.last_topic_id ?? null});
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not load your last lesson topic.'});
  }
});

app.put('/account/last-topic', requireAuth, async (request, response) => {
  const topicId = String(request.body.topicId ?? '').trim();
  if (!findTopic(topicId)) {
    return response.status(400).json({message: 'This lesson topic was not found.'});
  }
  try {
    await pool.query(
      'UPDATE accounts SET last_topic_id = $1 WHERE id = $2',
      [topicId, request.accountId],
    );
    return response.json({ok: true});
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not save your last lesson topic.'});
  }
});

app.put('/account/avatar-palette', requireAuth, async (request, response) => {
  const paletteIndex = Number(request.body.paletteIndex);
  if (!Number.isInteger(paletteIndex) || paletteIndex < 0 || paletteIndex > 20) {
    return response.status(400).json({message: 'Choose one of the available avatar palettes.'});
  }
  try {
    await pool.query(
      'UPDATE accounts SET avatar_palette_index = $1 WHERE id = $2',
      [paletteIndex, request.accountId],
    );
    return response.json({avatarPaletteIndex: paletteIndex});
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not save your avatar colors.'});
  }
});

app.put('/account/preferences', requireAuth, async (request, response) => {
  const preferredLanguage = String(request.body.preferredLanguage ?? '');
  const ageYears = Number(request.body.ageYears);
  if (!['en', 'fr', 'es', 'hi', 'ru'].includes(preferredLanguage)) {
    return response.status(400).json({message: 'Choose a supported language.'});
  }
  if (!Number.isInteger(ageYears) || ageYears < 1 || ageYears > 120) {
    return response.status(400).json({message: 'Choose an age between 1 and 120.'});
  }
  try {
    await pool.query(
      'UPDATE accounts SET preferred_language = $1, age_years = $2 WHERE id = $3',
      [preferredLanguage, ageYears, request.accountId],
    );
    return response.json({preferredLanguage, ageYears});
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not save your preferences.'});
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
  const durationSeconds = Number(request.body.durationSeconds ?? 0);
  const topic = findTopic(topicId);

  if (!topic) return response.status(404).json({message: 'This lesson topic was not found.'});
  if (!lessonId) {
    return response.status(400).json({message: 'Lesson is required.'});
  }
  if (
    !Number.isInteger(correctAnswers) ||
    !Number.isInteger(exerciseCount) ||
    !Number.isInteger(durationSeconds) ||
    exerciseCount < 1 ||
    exerciseCount > 100 ||
    correctAnswers < 0 ||
    correctAnswers > exerciseCount ||
    durationSeconds < 0 ||
    durationSeconds > 604800
  ) {
    return response.status(400).json({message: 'Lesson score is invalid.'});
  }

  const lessonNumber = Number(lessonId.replace('lesson-', ''));
  if (!Number.isInteger(lessonNumber) || lessonNumber < 1 || lessonNumber > topic.lessonCount) {
    return response.status(400).json({message: 'This lesson is not available.'});
  }

  const answerXp = (correctAnswers * 5) + ((exerciseCount - correctAnswers) * 2);

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
    const timeMultiplier = durationSeconds > 180 ? 0.8 : 1;
    const potionMultiplier = game.rows[0].boost_active ? 2 : 1;
    const earnedXp = Math.round(answerXp * timeMultiplier * potionMultiplier);
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
  const today = clientStudyDate(request);
  const offsetMinutes = clientTimezoneOffset(request);
  const localDateSql = "((created_at AT TIME ZONE 'UTC') + ($2::int * interval '1 minute'))::date";

  try {
    const [totals, daily, leaderboardRows] = await Promise.all([
      pool.query(
        'SELECT COALESCE(SUM(xp), 0)::int AS total_xp FROM lesson_xp WHERE account_id = $1',
        [accountId],
      ),
      pool.query(
        `SELECT ${localDateSql}::text AS date,
                SUM(xp)::int AS xp
         FROM lesson_xp
         WHERE account_id = $1
           AND ${localDateSql} BETWEEN ($3::date - 6) AND $3::date
         GROUP BY ${localDateSql}
         ORDER BY date`,
        [accountId, offsetMinutes, today],
      ),
      pool.query(
        `WITH account_totals AS (
           SELECT accounts.id, accounts.full_name, accounts.avatar_palette_index,
                  accounts.created_at,
                  COALESCE(SUM(lesson_xp.xp), 0)::int AS xp
           FROM accounts
           LEFT JOIN lesson_xp ON lesson_xp.account_id = accounts.id
           GROUP BY accounts.id
         ), ranked AS (
           SELECT id, full_name, avatar_palette_index, xp,
                  ROW_NUMBER() OVER (
                    ORDER BY xp DESC, created_at ASC, lower(full_name), id
                  )::int AS place
           FROM account_totals
         )
         SELECT id, full_name AS name, avatar_palette_index, xp, place
         FROM ranked
         WHERE place <= 10 OR id = $1
         ORDER BY place`,
        [accountId],
      ),
    ]);
    const xpByDate = new Map(daily.rows.map((row) => [row.date, row.xp]));
    const todayDate = new Date(`${today}T00:00:00.000Z`);
    const days = Array.from({length: 7}, (_item, index) => {
      const date = new Date(todayDate.valueOf() - (6 - index) * 86400000)
        .toISOString().slice(0, 10);
      return {date, xp: xpByDate.get(date) ?? 0};
    });
    const currentUser = leaderboardRows.rows.find((row) => row.id === accountId);
    const leaderboard = leaderboardRows.rows
      .filter((row) => row.place <= 10)
      .map(({id, name, xp, place, avatar_palette_index}) => ({
        name,
        xp,
        place,
        isYou: id === accountId,
        avatarPaletteIndex: avatar_palette_index,
      }));
    const yourPlace = currentUser?.place > 10
      ? {
          name: currentUser.name,
          xp: currentUser.xp,
          place: currentUser.place,
          isYou: true,
          avatarPaletteIndex: currentUser.avatar_palette_index,
        }
      : null;
    return response.json({totalXp: totals.rows[0].total_xp, days, leaderboard, yourPlace});
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
    `SELECT id, full_name, email, password_hash, avatar_palette_index,
            preferred_language, age_years
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
    avatarPaletteIndex: row.avatar_palette_index ?? 0,
    preferredLanguage: row.preferred_language ?? null,
    ageYears: row.age_years ?? null,
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
  await refreshHearts(accountId);
  await pool.query(
    `WITH moved AS (
       DELETE FROM study_days
       WHERE account_id = $1 AND study_date = $2::date + 1
       RETURNING account_id
     )
     INSERT INTO study_days (account_id, study_date)
     SELECT account_id, $2::date FROM moved
     ON CONFLICT DO NOTHING`,
    [accountId, today],
  );
  const [result, studyResult] = await Promise.all([
    pool.query(
      'SELECT hearts, heart_recharge_at, emeralds, xp_boost_until FROM account_gamification WHERE account_id = $1',
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
    heartRechargeAt: game.heart_recharge_at?.toISOString() ?? null,
    emeralds: game.emeralds,
    streakCount,
    studyDays,
    xpBoostUntil: game.xp_boost_until?.toISOString() ?? null,
  };
}

async function refreshHearts(accountId) {
  await pool.query(
    `UPDATE account_gamification
     SET hearts = LEAST(5, hearts + 1 + FLOOR(EXTRACT(EPOCH FROM (now() - heart_recharge_at)) / 10800)::int),
         heart_recharge_at = CASE
           WHEN hearts + 1 + FLOOR(EXTRACT(EPOCH FROM (now() - heart_recharge_at)) / 10800)::int >= 5
             THEN NULL
           ELSE heart_recharge_at +
             (1 + FLOOR(EXTRACT(EPOCH FROM (now() - heart_recharge_at)) / 10800)::int) * interval '3 hours'
         END
     WHERE account_id = $1 AND hearts < 5 AND heart_recharge_at IS NOT NULL
       AND heart_recharge_at <= now()`,
    [accountId],
  );
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

function clientTimezoneOffset(request) {
  const candidate = Number(request.get('X-Client-UTC-Offset-Minutes'));
  return Number.isInteger(candidate) && Math.abs(candidate) <= 840 ? candidate : 0;
}

pool.query(readFileSync(new URL('../schema.sql', import.meta.url), 'utf8')).then(async () => {
  await seedLeaderboardDemoUsers();
  await applyStudyDayBackfill();
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

async function seedLeaderboardDemoUsers() {
  const xpAmounts = [9, 11, 21, 43, 55, 77, 89, 121, 165, 197, 233, 271, 319, 371, 424];
  for (const [index, xp] of xpAmounts.entries()) {
    const number = String(index + 1).padStart(2, '0');
    const email = `leaderboard-demo-${number}@demo.howbuddy.invalid`;
    const name = `Demo Learner ${number}`;
    const account = await pool.query(
      `INSERT INTO accounts (full_name, email, auth_provider, provider_subject)
       VALUES ($1, $2, 'demo', $3)
       ON CONFLICT (email) DO UPDATE
       SET full_name = EXCLUDED.full_name,
           auth_provider = 'demo', password_hash = NULL,
           provider_subject = EXCLUDED.provider_subject
       RETURNING id`,
      [name, email, `leaderboard-demo-${number}`],
    );
    await pool.query(
      `INSERT INTO lesson_xp (account_id, topic_id, lesson_id, xp)
       VALUES ($1, '__leaderboard_demo__', 'seeded-total', $2)
       ON CONFLICT (account_id, topic_id, lesson_id)
       DO UPDATE SET xp = EXCLUDED.xp`,
      [account.rows[0].id, xp],
    );
  }
  console.log('Leaderboard demo users are seeded.');
}

async function applyStudyDayBackfill() {
  const email = String(process.env.STUDY_HISTORY_BACKFILL_EMAIL ?? '').trim().toLowerCase();
  const endDate = String(process.env.STUDY_HISTORY_BACKFILL_END_DATE ?? '').trim();
  if (!email && !endDate) return;
  if (!email || !/^\d{4}-\d{2}-\d{2}$/.test(endDate)) {
    throw new Error('Study history backfill needs an account email and a YYYY-MM-DD end date.');
  }
  const parsedDate = new Date(`${endDate}T00:00:00.000Z`);
  if (Number.isNaN(parsedDate.valueOf()) || parsedDate.toISOString().slice(0, 10) !== endDate) {
    throw new Error('Study history backfill end date is not a valid calendar date.');
  }
  const result = await pool.query(
    `INSERT INTO study_days (account_id, study_date)
     SELECT accounts.id, $2::date - dates.day_offset
     FROM accounts
     CROSS JOIN generate_series(1, 4) AS dates(day_offset)
     WHERE lower(accounts.email) = $1
     ON CONFLICT DO NOTHING`,
    [email, endDate],
  );
  const xpResult = await pool.query(
    `WITH target_account AS (
       SELECT id FROM accounts WHERE lower(email) = $1
     ), backfill_days AS (
       SELECT target_account.id AS account_id,
              ($2::date - days.day_offset)::date AS xp_date
       FROM target_account
       CROSS JOIN generate_series(1, 4) AS days(day_offset)
     )
     INSERT INTO lesson_xp (account_id, topic_id, lesson_id, xp, created_at)
     SELECT account_id,
            '__history_backfill__',
            'day-' || xp_date::text,
            floor(random() * 95)::int + 9,
            (xp_date + time '12:00') AT TIME ZONE 'UTC'
     FROM backfill_days
     ON CONFLICT DO NOTHING
     RETURNING xp, (created_at AT TIME ZONE 'UTC')::date::text AS date`,
    [email, endDate],
  );
  console.log(`Historical study-day backfill inserted ${result.rowCount} rows.`);
  console.log(
    `Historical XP backfill inserted ${xpResult.rowCount} rows: ${xpResult.rows
      .map((row) => `${row.date}=${row.xp}`)
      .join(', ')}`,
  );
}
