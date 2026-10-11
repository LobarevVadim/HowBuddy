import {createHash, randomUUID} from 'node:crypto';
import {createServer} from 'node:http';
import {existsSync, readFileSync} from 'node:fs';

const port = Number(process.env.PORT ?? 3000);
const accounts = new Map();
const completedLessons = new Map();
const completedTopics = new Set();
const xpEvents = new Map();
const gameAccounts = new Map();
const lessonContentPath = ['server/data/lesson_exercises.json', 'data/lesson_exercises.json']
  .find((path) => existsSync(path));
if (!lessonContentPath) throw new Error('Lesson exercise JSON database was not found.');
const lessonContent = JSON.parse(readFileSync(lessonContentPath, 'utf8'));

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
    send(response, 200, {topics: rootTopics()});
    return;
  }

  if (url.pathname === '/gamification' && request.method === 'GET') {
    const accountId = String(url.searchParams.get('accountId') ?? '').trim();
    if (!accountId) {
      send(response, 400, {message: 'Account is required.'});
      return;
    }
    send(response, 200, publicGameState(accountId, clientStudyDate(request)));
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
    refreshHearts(game);
    const lessonAllowed = game.hearts > 0;
    if (lessonAllowed) {
      if (game.hearts === 5) game.heartRechargeAt = new Date(Date.now() + 3 * 60 * 60 * 1000);
      else if (!game.heartRechargeAt) game.heartRechargeAt = new Date(Date.now() + 3 * 60 * 60 * 1000);
      game.hearts--;
    }
    send(response, 200, {lessonAllowed, ...publicGameState(accountId, clientStudyDate(request))});
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
    refreshHearts(game);
    game.hearts = Math.min(5, game.hearts + 1);
    if (game.hearts >= 5) game.heartRechargeAt = null;
    else if (!game.heartRechargeAt) game.heartRechargeAt = new Date(Date.now() + 3 * 60 * 60 * 1000);
    send(response, 200, publicGameState(accountId, clientStudyDate(request)));
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
    send(response, 200, publicGameState(accountId, clientStudyDate(request)));
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
    send(response, 200, publicGameState(accountId, clientStudyDate(request)));
    return;
  }

  if (url.pathname === '/lessons/tree' && request.method === 'GET') {
    const topicId = url.searchParams.get('topic') ?? lessonContent.roots[0];
    const topic = findTopic(topicId);
    if (!topic) {
      send(response, 404, {message: 'This lesson topic was not found.'});
      return;
    }
    send(response, 200, {
      topic,
      levels: buildLessonLevels(topic),
      nextQuestions: getNextQuestions(topic.id),
    });
    return;
  }

  if (url.pathname === '/lessons/exercises' && request.method === 'GET') {
    const topicId = String(url.searchParams.get('topic') ?? '').trim();
    const lessonId = String(url.searchParams.get('lesson') ?? 'lesson-1').trim();
    const topicContent = lessonContent.nodes[topicId];
    if (!topicContent) {
      send(response, 404, {message: 'No exercises are available for this topic.'});
      return;
    }
    const lessonNumber = Number(lessonId.replace('lesson-', ''));
    const extraNodeId = topicContent.extraLessons[lessonNumber - 2];
    const lesson = lessonNumber === 1 ? topicContent : lessonContent.nodes[extraNodeId];
    if (!lesson || !Number.isInteger(lessonNumber)) {
      send(response, 404, {message: 'This lesson is not available.'});
      return;
    }
    send(response, 200, {topic: topicId, content: lesson.content, exercises: lesson.exercises});
    return;
  }

  if (url.pathname === '/lessons/complete' && request.method === 'POST') {
    const body = await readJson(request);
    const topicId = String(body.topicId ?? '').trim();
    const lessonId = String(body.lessonId ?? '').trim();
    const accountId = String(body.accountId ?? '').trim();
    const topic = findTopic(topicId);

    if (!topic) {
      send(response, 404, {message: 'This lesson topic was not found.'});
      return;
    }
    if (!lessonId || !accountId) {
      send(response, 400, {message: 'Lesson and account are required.'});
      return;
    }
    const correctAnswers = Number(body.correctAnswers);
    const exerciseCount = Number(body.exerciseCount);
    const durationSeconds = Number(body.durationSeconds ?? 0);
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
    game.studyDays.add(clientStudyDate(request));
    if (!xpEvents.has(key)) {
      const answerXp = (correctAnswers * 5) + ((exerciseCount - correctAnswers) * 2);
      const boostIsActive = game.xpBoostUntil && game.xpBoostUntil > new Date();
      const timeMultiplier = durationSeconds > 180 ? 0.8 : 1;
      earnedXp = Math.round(answerXp * timeMultiplier * (boostIsActive ? 2 : 1));
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
    const today = clientStudyDate(request);
    const offsetMinutes = clientTimezoneOffset(request);
    const todayDate = new Date(`${today}T00:00:00.000Z`);
    const days = Array.from({length: 7}, (_item, index) => {
      const date = new Date(todayDate.valueOf() - (6 - index) * 86400000);
      const dateKey = date.toISOString().slice(0, 10);
      const xp = [...xpEvents.values()]
        .filter((event) => event.accountId === accountId &&
          new Date(event.at.valueOf() + offsetMinutes * 60000).toISOString().slice(0, 10) === dateKey)
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

function buildNotepadTree() {
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
      heartRechargeAt: null,
      emeralds: 100,
      xpBoostUntil: null,
      studyDays: new Set(),
    });
  }
  return gameAccounts.get(accountId);
}

function publicGameState(accountId, today = new Date().toISOString().slice(0, 10)) {
  const game = getGameAccount(accountId);
  refreshHearts(game);
  const nextDay = new Date(`${today}T00:00:00.000Z`);
  nextDay.setUTCDate(nextDay.getUTCDate() + 1);
  const incorrectlyRecordedTomorrow = nextDay.toISOString().slice(0, 10);
  if (game.studyDays.delete(incorrectlyRecordedTomorrow)) game.studyDays.add(today);
  const days = new Set([...game.studyDays].filter((day) => day <= today));
  let cursor = new Date(`${today}T00:00:00.000Z`);
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
    heartRechargeAt: game.heartRechargeAt?.toISOString() ?? null,
    emeralds: game.emeralds,
    streakCount,
    studyDays: [...days],
    xpBoostUntil: game.xpBoostUntil?.toISOString() ?? null,
  };
}

function refreshHearts(game) {
  if (game.hearts >= 5 || !game.heartRechargeAt || game.heartRechargeAt > new Date()) return;
  const elapsedIntervals = Math.floor((Date.now() - game.heartRechargeAt.valueOf()) / (3 * 60 * 60 * 1000)) + 1;
  const added = Math.min(elapsedIntervals, 5 - game.hearts);
  game.hearts += added;
  game.heartRechargeAt = game.hearts >= 5
    ? null
    : new Date(game.heartRechargeAt.valueOf() + added * 3 * 60 * 60 * 1000);
}

function clientStudyDate(request) {
  const candidate = request.headers['x-client-date'];
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
  const candidate = Number(request.headers['x-client-utc-offset-minutes']);
  return Number.isInteger(candidate) && Math.abs(candidate) <= 840 ? candidate : 0;
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
