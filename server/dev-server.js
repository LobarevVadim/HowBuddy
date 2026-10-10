import {createHash, randomUUID} from 'node:crypto';
import {createServer} from 'node:http';

const port = Number(process.env.PORT ?? 3000);
const accounts = new Map();
const completedLessons = new Map();
const completedTopics = new Set();
const xpEvents = new Map();
const gameAccounts = new Map();

const server = createServer(async (request, response) => {
  const url = new URL(request.url, `http://localhost:${port}`);
  response.setHeader('Access-Control-Allow-Origin', '*');
  response.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  response.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  response.setHeader('Content-Type', 'application/json');

  if (request.method === 'OPTIONS') {
    response.writeHead(204);
    response.end();
    return;
  }

  if (url.pathname === '/health' && request.method === 'GET') {
    send(response, 200, {ok: true});
    return;
  }

  if (url.pathname === '/auth/register' && request.method === 'POST') {
    const body = await readJson(request);
    const fullName = String(body.fullName ?? '').trim();
    const email = String(body.email ?? '').trim().toLowerCase();
    const password = String(body.password ?? '');

    if (fullName.length < 2 || !email.includes('@') || password.length < 8) {
      send(response, 400, {message: 'Please complete all fields correctly.'});
      return;
    }

    if (accounts.has(email)) {
      send(response, 409, {message: 'An account already exists for this email.'});
      return;
    }

    const account = {
      id: randomUUID(),
      fullName,
      email,
      passwordHash: hash(password),
    };
    accounts.set(email, account);
    send(response, 201, {account: publicAccount(account)});
    return;
  }

  if (url.pathname === '/auth/social-signup' && request.method === 'POST') {
    const body = await readJson(request);
    const provider = String(body.provider ?? '').trim().toLowerCase();
    const fullName = String(body.displayName ?? '').trim();
    const email = String(body.email ?? '').trim().toLowerCase();

    if (!['google', 'apple'].includes(provider) || fullName.length < 2 || !email.includes('@')) {
      send(response, 400, {message: 'Social sign up details are invalid.'});
      return;
    }

    const existingAccount = accounts.get(email);
    if (existingAccount) {
      send(response, 200, {account: publicAccount(existingAccount)});
      return;
    }

    const account = {
      id: randomUUID(),
      fullName,
      email,
      provider,
      providerSubject: `${provider}:${email}`,
      passwordHash: null,
    };
    accounts.set(email, account);
    send(response, 201, {account: publicAccount(account)});
    return;
  }

  if (url.pathname === '/onboarding/topics' && request.method === 'GET') {
    send(response, 200, {topics});
    return;
  }

  if (url.pathname === '/gamification' && request.method === 'GET') {
    const accountId = String(url.searchParams.get('accountId') ?? '').trim();
    if (!accountId) {
      send(response, 400, {message: 'Account is required.'});
      return;
    }
    send(response, 200, publicGameState(accountId));
    return;
  }

  if (url.pathname === '/gamification/lesson-start' && request.method === 'POST') {
    const body = await readJson(request);
    const accountId = String(body.accountId ?? '').trim();
    if (!accountId) {
      send(response, 400, {message: 'Account is required.'});
      return;
    }
    const game = getGameAccount(accountId);
    const lessonAllowed = game.hearts > 0;
    if (lessonAllowed) game.hearts--;
    send(response, 200, {lessonAllowed, ...publicGameState(accountId)});
    return;
  }

  if (url.pathname === '/gamification/heart-video' && request.method === 'POST') {
    const body = await readJson(request);
    const accountId = String(body.accountId ?? '').trim();
    if (!accountId) {
      send(response, 400, {message: 'Account is required.'});
      return;
    }
    const game = getGameAccount(accountId);
    game.hearts = Math.min(5, game.hearts + 1);
    send(response, 200, publicGameState(accountId));
    return;
  }

  if (url.pathname === '/gamification/emerald-video' && request.method === 'POST') {
    const body = await readJson(request);
    const accountId = String(body.accountId ?? '').trim();
    if (!accountId) {
      send(response, 400, {message: 'Account is required.'});
      return;
    }
    getGameAccount(accountId).emeralds += 25;
    send(response, 200, publicGameState(accountId));
    return;
  }

  if (url.pathname === '/gamification/xp-boost' && request.method === 'POST') {
    const body = await readJson(request);
    const accountId = String(body.accountId ?? '').trim();
    const durationMinutes = Number(body.durationMinutes);
    const price = new Map([[60, 80], [30, 45], [10, 20]]).get(durationMinutes);
    if (!accountId || !price) {
      send(response, 400, {message: 'That XP boost is not available.'});
      return;
    }
    const game = getGameAccount(accountId);
    if (game.emeralds < price) {
      send(response, 400, {message: 'You do not have enough emeralds.'});
      return;
    }
    game.emeralds -= price;
    const now = new Date();
    const boostStart = game.xpBoostUntil && game.xpBoostUntil > now
      ? game.xpBoostUntil
      : now;
    game.xpBoostUntil = new Date(boostStart.getTime() + durationMinutes * 60_000);
    send(response, 200, publicGameState(accountId));
    return;
  }

  if (url.pathname === '/lessons/tree' && request.method === 'GET') {
    const topicId = url.searchParams.get('topic') ?? 'immortal';
    const topic = findTopic(topicId);
    send(response, 200, {
      topic,
      levels: buildLessonLevels(topic),
      nextQuestions: getNextQuestions(topic.id),
    });
    return;
  }

  if (url.pathname === '/lessons/complete' && request.method === 'POST') {
    const body = await readJson(request);
    const topicId = String(body.topicId ?? '').trim();
    const lessonId = String(body.lessonId ?? '').trim();
    const accountId = String(body.accountId ?? '').trim();
    const topic = findTopic(topicId);

    if (!lessonId || !accountId) {
      send(response, 400, {message: 'Lesson and account are required.'});
      return;
    }
    const correctAnswers = Number(body.correctAnswers);
    const exerciseCount = Number(body.exerciseCount);
    if (!Number.isInteger(correctAnswers) || !Number.isInteger(exerciseCount) || exerciseCount < 1) {
      send(response, 400, {message: 'Lesson score is invalid.'});
      return;
    }

    const lessonSet = getCompletedLessonSet(topic.id);
    lessonSet.add(lessonId);

    const topicCompleted = lessonSet.size >= Math.min(topic.lessonCount, 20);
    if (topicCompleted) {
      completedTopics.add(topic.id);
    }

    const key = `${accountId}:${topic.id}:${lessonId}`;
    let earnedXp = 0;
    const game = getGameAccount(accountId);
    game.studyDays.add(new Date().toISOString().slice(0, 10));
    if (!xpEvents.has(key)) {
      const baseXp = 25 + Math.round(10 * Math.max(0, Math.min(correctAnswers, exerciseCount)) / exerciseCount);
      const boostIsActive = game.xpBoostUntil && game.xpBoostUntil > new Date();
      earnedXp = baseXp * (boostIsActive ? 2 : 1);
      xpEvents.set(key, {accountId, earnedXp, at: new Date()});
    }

    const totalXp = [...xpEvents.values()]
      .filter((event) => event.accountId === accountId)
      .reduce((sum, event) => sum + event.earnedXp, 0);
    send(response, 200, {ok: true, topicCompleted, earnedXp, totalXp});
    return;
  }

  if (url.pathname === '/xp/weekly' && request.method === 'GET') {
    const accountId = String(url.searchParams.get('accountId') ?? '').trim();
    if (!accountId) {
      send(response, 400, {message: 'Account is required.'});
      return;
    }
    const today = new Date();
    const days = Array.from({length: 7}, (_item, index) => {
      const date = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate() - 6 + index));
      const dateKey = date.toISOString().slice(0, 10);
      const xp = [...xpEvents.values()]
        .filter((event) => event.accountId === accountId && event.at.toISOString().slice(0, 10) === dateKey)
        .reduce((sum, event) => sum + event.earnedXp, 0);
      return {date: dateKey, xp};
    });
    const totalXp = [...xpEvents.values()]
      .filter((event) => event.accountId === accountId)
      .reduce((sum, event) => sum + event.earnedXp, 0);
    send(response, 200, {totalXp, days});
    return;
  }

  if (url.pathname === '/notepad/tree' && request.method === 'GET') {
    send(response, 200, {tree: buildNotepadTree()});
    return;
  }

  if (url.pathname === '/auth/login' && request.method === 'POST') {
    const body = await readJson(request);
    const identifier = String(body.identifier ?? '').trim().toLowerCase();
    const password = String(body.password ?? '');
    const account = accounts.get(identifier);

    if (!account || !account.passwordHash || account.passwordHash !== hash(password)) {
      send(response, 401, {message: 'Invalid email, username, or password.'});
      return;
    }

    send(response, 200, {account: publicAccount(account)});
    return;
  }

  send(response, 404, {message: 'Not found.'});
});

server.listen(port, () => {
  console.log(`HowBuddy dev account server listening on http://localhost:${port}`);
});

function hash(value) {
  return createHash('sha256').update(value).digest('hex');
}

function publicAccount(account) {
  return {
    id: account.id,
    fullName: account.fullName,
    email: account.email,
  };
}

function send(response, statusCode, body) {
  response.writeHead(statusCode);
  response.end(JSON.stringify(body));
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

function getGameAccount(accountId) {
  if (!gameAccounts.has(accountId)) {
    gameAccounts.set(accountId, {
      hearts: 5,
      emeralds: 100,
      xpBoostUntil: null,
      studyDays: new Set(),
    });
  }
  return gameAccounts.get(accountId);
}

function publicGameState(accountId) {
  const game = getGameAccount(accountId);
  const days = game.studyDays;
  const now = new Date();
  let cursor = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
  if (!days.has(cursor.toISOString().slice(0, 10))) {
    cursor.setUTCDate(cursor.getUTCDate() - 1);
  }

  let streakCount = 0;
  while (days.has(cursor.toISOString().slice(0, 10))) {
    streakCount++;
    cursor.setUTCDate(cursor.getUTCDate() - 1);
  }

  return {
    hearts: game.hearts,
    emeralds: game.emeralds,
    streakCount,
    studyDays: [...days],
    xpBoostUntil: game.xpBoostUntil?.toISOString() ?? null,
  };
}

async function readJson(request) {
  const chunks = [];
  for await (const chunk of request) {
    chunks.push(chunk);
  }

  if (chunks.length === 0) {
    return {};
  }

  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
}
