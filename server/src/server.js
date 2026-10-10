import bcrypt from 'bcryptjs';
import cors from 'cors';
import dotenv from 'dotenv';
import express from 'express';
import pg from 'pg';

dotenv.config();

const app = express();
const port = Number(process.env.PORT ?? 3000);
const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
});
const completedLessons = new Map();
const completedTopics = new Set();

app.use(cors());
app.use(express.json());

app.get('/health', (_request, response) => {
  response.json({ok: true});
});

app.get('/onboarding/topics', (_request, response) => {
  response.json({topics});
});

app.get('/gamification', async (request, response) => {
  const accountId = String(request.query.accountId ?? '').trim();
  if (!accountId) return response.status(400).json({message: 'Account is required.'});
  try {
    return response.json(await getGameState(accountId));
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not load game progress.'});
  }
});

app.post('/gamification/lesson-start', async (request, response) => {
  const accountId = String(request.body.accountId ?? '').trim();
  if (!accountId) return response.status(400).json({message: 'Account is required.'});
  try {
    await ensureGameRow(accountId);
    const result = await pool.query(
      'UPDATE account_gamification SET hearts = hearts - 1 WHERE account_id = $1 AND hearts > 0 RETURNING hearts',
      [accountId],
    );
    return response.json({lessonAllowed: result.rowCount === 1, ...await getGameState(accountId)});
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not use a lesson heart.'});
  }
});

app.post('/gamification/heart-video', async (request, response) => {
  const accountId = String(request.body.accountId ?? '').trim();
  if (!accountId) return response.status(400).json({message: 'Account is required.'});
  try {
    await ensureGameRow(accountId);
    await pool.query(
      'UPDATE account_gamification SET hearts = LEAST(5, hearts + 1) WHERE account_id = $1',
      [accountId],
    );
    return response.json(await getGameState(accountId));
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not restore a heart.'});
  }
});

app.post('/gamification/emerald-video', async (request, response) => {
  const accountId = String(request.body.accountId ?? '').trim();
  if (!accountId) return response.status(400).json({message: 'Account is required.'});
  try {
    await ensureGameRow(accountId);
    await pool.query(
      'UPDATE account_gamification SET emeralds = emeralds + 25 WHERE account_id = $1',
      [accountId],
    );
    return response.json(await getGameState(accountId));
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not add emeralds.'});
  }
});

app.post('/gamification/xp-boost', async (request, response) => {
  const accountId = String(request.body.accountId ?? '').trim();
  const minutes = Number(request.body.durationMinutes);
  const price = new Map([[60, 80], [30, 45], [10, 20]]).get(minutes);
  if (!accountId || !price) {
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
    return response.json(await getGameState(accountId));
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

    return response.status(201).json({account: toAccount(result.rows[0])});
  } catch (error) {
    if (error.code === '23505') {
      return response.status(409).json({message: 'An account already exists for this email.'});
    }

    console.error(error);
    return response.status(500).json({message: 'Could not create account.'});
  }
});

app.post('/auth/social-signup', async (request, response) => {
  const provider = String(request.body.provider ?? '').trim().toLowerCase();
  const fullName = String(request.body.displayName ?? '').trim();
  const email = String(request.body.email ?? '').trim().toLowerCase();

  if (!['google', 'apple'].includes(provider) || fullName.length < 2 || !email.includes('@')) {
    return response.status(400).json({message: 'Social sign up details are invalid.'});
  }

  try {
    const existing = await pool.query(
      `SELECT id, full_name, email
       FROM accounts
       WHERE email = $1
       LIMIT 1`,
      [email],
    );

    if (existing.rows[0]) {
      return response.json({account: toAccount(existing.rows[0])});
    }

    const result = await pool.query(
      `INSERT INTO accounts (full_name, email, auth_provider, provider_subject)
       VALUES ($1, $2, $3, $4)
       RETURNING id, full_name, email`,
      [fullName, email, provider, `${provider}:${email}`],
    );

    return response.status(201).json({account: toAccount(result.rows[0])});
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not create social account.'});
  }
});

app.get('/lessons/tree', (request, response) => {
  const topic = findTopic(String(request.query.topic ?? 'immortal'));
  response.json({
    topic,
    levels: buildLessonLevels(topic),
    nextQuestions: getNextQuestions(topic.id),
  });
});

app.post('/lessons/complete', async (request, response) => {
  const topicId = String(request.body.topicId ?? '').trim();
  const lessonId = String(request.body.lessonId ?? '').trim();
  const accountId = String(request.body.accountId ?? '').trim();
  const correctAnswers = Number(request.body.correctAnswers);
  const exerciseCount = Number(request.body.exerciseCount);
  const topic = findTopic(topicId);

  if (!lessonId || !accountId) {
    return response.status(400).json({message: 'Lesson and account are required.'});
  }
  if (
    !Number.isInteger(correctAnswers) ||
    !Number.isInteger(exerciseCount) ||
    exerciseCount < 1
  ) {
    return response.status(400).json({message: 'Lesson score is invalid.'});
  }

  const lessonSet = getCompletedLessonSet(topic.id);
  lessonSet.add(lessonId);

  const topicCompleted = lessonSet.size >= Math.min(topic.lessonCount, 20);
  if (topicCompleted) {
    completedTopics.add(topic.id);
  }

  const baseXp = 25 + Math.round(
    10 * Math.max(0, Math.min(correctAnswers, exerciseCount)) / exerciseCount,
  );

  try {
    await ensureGameRow(accountId);
    await pool.query(
      'INSERT INTO study_days (account_id, study_date) VALUES ($1, (now() AT TIME ZONE \'UTC\')::date) ON CONFLICT DO NOTHING',
      [accountId],
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

app.get('/xp/weekly', async (request, response) => {
  const accountId = String(request.query.accountId ?? '').trim();
  if (!accountId) {
    return response.status(400).json({message: 'Account is required.'});
  }

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

app.get('/notepad/tree', (_request, response) => {
  response.json({tree: buildNotepadTree()});
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

  return response.json({account: toAccount(account)});
});

function toAccount(row) {
  return {
    id: row.id,
    fullName: row.full_name,
    email: row.email,
  };
}

const topics = [
  {
    id: 'immortal',
    question: 'Could we be immortal?',
    lessonCount: 20,
  },
  {
    id: 'poop-smell',
    question: 'Who poop smells bad?',
    lessonCount: 15,
  },
  {
    id: 'monkeys-evolve',
    question: 'Why do monkeys not eveoleve?',
    lessonCount: 10,
  },
];

const nextQuestionsByTopic = {
  'poop-smell': ['Question1', 'Question2', 'Question3'],
  'monkeys-evolve': ['Question4', 'Question5', 'Question6'],
  immortal: ['Question7', 'Question8', 'Question9'],
};

function findTopic(topicId) {
  const topic = topics.find((item) => item.id === topicId);
  if (topic) {
    return topic;
  }

  if (/^Question[1-9]$/.test(topicId)) {
    return {
      id: topicId,
      question: topicId,
      lessonCount: 10,
    };
  }

  return topics[0];
}

function getNextQuestions(topicId) {
  if (nextQuestionsByTopic[topicId]) {
    return nextQuestionsByTopic[topicId];
  }

  if (/^Question[1-9]$/.test(topicId)) {
    return [1, 2, 3].map((index) => `${topicId}.${index}`);
  }

  return [];
}

function buildLessonLevels(topic) {
  const shapes = ['star', 'triangle', 'hexagon', 'square', 'circle'];
  const count = Math.min(topic.lessonCount, 20);
  const lessonSet = getCompletedLessonSet(topic.id);

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
      title: `Lesson ${level}`,
      isCompleted,
      isUnlocked,
    };
  });
}

function buildNotepadTree() {
  return {
    id: 'main-tree',
    title: 'Main Tree',
    isCompleted: topics.every((topic) => completedTopics.has(topic.id)),
    children: topics.map((topic) => ({
      id: topic.id,
      title: topic.question,
      isCompleted: completedTopics.has(topic.id),
      children: (nextQuestionsByTopic[topic.id] ?? []).map((question) => ({
        id: question,
        title: question,
        isCompleted: completedTopics.has(question),
        children: [1, 2, 3].map((index) => ({
          id: `${question}.${index}`,
          title: `${question}.${index}`,
          isCompleted: completedTopics.has(question),
          children: [],
        })),
      })),
    })),
  };
}

function getCompletedLessonSet(topicId) {
  if (!completedLessons.has(topicId)) {
    completedLessons.set(topicId, new Set());
  }

  return completedLessons.get(topicId);
}

async function ensureGameRow(accountId) {
  await pool.query(
    'INSERT INTO account_gamification (account_id) VALUES ($1) ON CONFLICT (account_id) DO NOTHING',
    [accountId],
  );
}

async function getGameState(accountId) {
  await ensureGameRow(accountId);
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
  const studyDays = studyResult.rows.map((row) => row.day);
  const studied = new Set(studyDays);
  const now = new Date();
  let cursor = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
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

pool.query(`
  CREATE TABLE IF NOT EXISTS lesson_xp (
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    topic_id TEXT NOT NULL,
    lesson_id TEXT NOT NULL,
    xp INTEGER NOT NULL CHECK (xp BETWEEN 25 AND 70),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (account_id, topic_id, lesson_id)
  );
  ALTER TABLE lesson_xp DROP CONSTRAINT IF EXISTS lesson_xp_xp_check;
  ALTER TABLE lesson_xp ADD CONSTRAINT lesson_xp_xp_check CHECK (xp BETWEEN 25 AND 70);
  CREATE TABLE IF NOT EXISTS study_days (
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    study_date DATE NOT NULL,
    PRIMARY KEY (account_id, study_date)
  );
  CREATE TABLE IF NOT EXISTS account_gamification (
    account_id UUID PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
    hearts INTEGER NOT NULL DEFAULT 5 CHECK (hearts BETWEEN 0 AND 5),
    emeralds INTEGER NOT NULL DEFAULT 100 CHECK (emeralds >= 0),
    xp_boost_until TIMESTAMPTZ
  );
`).then(() => {
  app.listen(port, () => {
    console.log(`HowBuddy auth API listening on http://localhost:${port}`);
  });
}).catch((error) => {
  console.error('Could not initialize the XP table.', error);
  process.exitCode = 1;
});
