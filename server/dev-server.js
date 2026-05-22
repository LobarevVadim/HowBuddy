import {createHash, randomUUID} from 'node:crypto';
import {createServer} from 'node:http';

const port = Number(process.env.PORT ?? 3000);
const accounts = new Map();

const server = createServer(async (request, response) => {
  response.setHeader('Access-Control-Allow-Origin', '*');
  response.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  response.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  response.setHeader('Content-Type', 'application/json');

  if (request.method === 'OPTIONS') {
    response.writeHead(204);
    response.end();
    return;
  }

  if (request.url === '/health' && request.method === 'GET') {
    send(response, 200, {ok: true});
    return;
  }

  if (request.url === '/auth/register' && request.method === 'POST') {
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

  if (request.url === '/auth/social-signup' && request.method === 'POST') {
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

  if (request.url === '/auth/login' && request.method === 'POST') {
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
