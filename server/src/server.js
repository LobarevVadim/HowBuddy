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

app.post('/lessons/complete', (request, response) => {
  const topicId = String(request.body.topicId ?? '').trim();
  const lessonId = String(request.body.lessonId ?? '').trim();
  const topic = findTopic(topicId);

  if (!lessonId) {
    return response.status(400).json({message: 'Lesson is missing.'});
  }

  const lessonSet = getCompletedLessonSet(topic.id);
  lessonSet.add(lessonId);

  const topicCompleted = lessonSet.size >= Math.min(topic.lessonCount, 20);
  if (topicCompleted) {
    completedTopics.add(topic.id);
  }

  return response.json({ok: true, topicCompleted});
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

app.listen(port, () => {
  console.log(`HowBuddy auth API listening on http://localhost:${port}`);
});
