import test from 'node:test';
import assert from 'node:assert/strict';
import {once} from 'node:events';
import {createHttpApp} from './http_app.js';

test('rejected route and middleware promises return safe JSON without leaking details', async (t) => {
  const errors = [];
  const app = createHttpApp({reportError: (error) => errors.push(error)});
  app.get('/route', async () => { throw new Error('private database details'); });
  app.get('/middleware', async () => { throw new Error('private middleware details'); }, (_req, res) => res.json({ok: true}));
  app.post('/json', (req, res) => res.json(req.body));
  const server = app.listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => new Promise((resolve) => { server.closeAllConnections(); server.close(resolve); }));
  for (const path of ['/route', '/middleware']) {
    const response = await fetch(`http://127.0.0.1:${server.address().port}${path}`);
    assert.equal(response.status, 500);
    assert.deepEqual(await response.json(), {code: 'internal_error', message: 'Something went wrong. Please try again.'});
  }
  assert.equal(errors.length, 2);
  const malformed = await fetch(`http://127.0.0.1:${server.address().port}/json`, {
    method: 'POST', headers: {'Content-Type': 'application/json'}, body: '{',
  });
  assert.equal(malformed.status, 400);
  assert.equal((await malformed.json()).code, 'invalid_json');
});
