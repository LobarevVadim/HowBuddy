import {createHash, randomUUID} from 'node:crypto';
import {createServer} from 'node:http';

const port = Number(process.env.PORT ?? 3000);
const accounts = new Map();

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

  if (url.pathname === '/lessons/tree' && request.method === 'GET') {
    const topicId = url.searchParams.get('topic') ?? 'immortal';
    const topic = findTopic(topicId);
    send(response, 200, {
      topic,
      levels: buildLessonLevels(topic),
      nextQuestions: nextQuestionsByTopic[topic.id],
    });
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
  return topics.find((topic) => topic.id === topicId) ?? topics[0];
}

function buildLessonLevels(topic) {
  const shapes = ['star', 'triangle', 'hexagon', 'square', 'circle'];
  const count = Math.min(topic.lessonCount, 20);

  return Array.from({length: count}, (_item, index) => {
    const level = index + 1;
    return {
      id: `lesson-${level}`,
      level,
      shape: shapes[index % shapes.length],
      title: `Lesson ${level}`,
    };
  });
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
