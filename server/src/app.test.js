import test from 'node:test';
import assert from 'node:assert/strict';
import {once} from 'node:events';
import {createHowBuddyApi} from './app.js';
import {createTestDatabase} from './test_database.js';

test('HTTP login → start → answer → complete → retry; auth isolation and study history survive reads',
  {skip: !process.env.HOWBUDDY_TEST_DATABASE_URL}, async (t) => {
    process.env.SESSION_SECRET = 'test-only-secret-at-least-32-characters';
    const pool = await createTestDatabase(t);
    let published = true;
    const content = {roots: ['cells'], nodes: {cells: {id: 'cells', question: 'What are cells?', content: 'Small living units.', children: [], lessonCount: 1,
      exercises: [{type: 'singleChoice', prompt: 'Which is living?', options: ['Cell', 'Rock'], correctAnswers: ['Cell']}]}}};
    const {app} = createHowBuddyApi({databasePool: pool, enableIntegrations: false, contentProvider: async () => published ? content : {roots: [], nodes: {}}});
    const server = app.listen(0, '127.0.0.1');
    await once(server, 'listening');
    t.after(() => new Promise((resolve) => { server.closeAllConnections(); server.close(resolve); }));
    const origin = `http://127.0.0.1:${server.address().port}`;
    let token;
    const request = async (path, body) => {
      const response = await fetch(origin + path, {method: body ? 'POST' : 'GET',
        headers: {'Content-Type': 'application/json', ...(token ? {Authorization: `Bearer ${token}`} : {})},
        ...(body ? {body: JSON.stringify(body)} : {})});
      return {status: response.status, body: await response.json()};
    };
    assert.equal((await request('/gamification')).status, 401);
    const registered = await request('/auth/register', {fullName: 'Test Learner', email: 'learner@example.invalid', password: 'Test-password-123!'});
    assert.equal(registered.status, 201);
    const login = await request('/auth/login', {identifier: 'learner@example.invalid', password: 'Test-password-123!'});
    assert.equal(login.status, 200);
    token = login.body.sessionToken;
    const accountId = login.body.account.id;
    const start = await request('/lessons/start', {topicId: 'cells', lessonId: 'lesson-1', requestId: 'start-1'});
    assert.equal(start.status, 200);
    assert.equal(start.body.hearts, 4);
    const replayStart = await request('/lessons/start', {topicId: 'cells', lessonId: 'lesson-1', requestId: 'start-1'});
    assert.equal(replayStart.body.sessionId, start.body.sessionId);
    assert.equal(replayStart.body.hearts, 4);
    const secondStart = await request('/lessons/start', {topicId: 'cells', lessonId: 'lesson-1', requestId: 'start-2'});
    assert.equal(secondStart.body.hearts, 3);
    const input = {topicId: 'cells', lessonId: 'lesson-1', completionId: start.body.sessionId, correctAnswers: 100, exerciseCount: 100};
    assert.equal((await request('/lessons/complete', input)).status, 409);
    const attempt = await request('/bobo/attempts', {topicId: 'cells', lessonId: 'lesson-1', sessionId: start.body.sessionId, exerciseIndex: 0, studentAnswer: 'cell', response: 'cell'});
    assert.equal(attempt.status, 200);
    assert.equal(attempt.body.correct, true);
    const otherAttempt = await request('/bobo/attempts', {topicId: 'cells', lessonId: 'lesson-1', sessionId: secondStart.body.sessionId, exerciseIndex: 0, studentAnswer: 'Rock'});
    assert.equal(otherAttempt.body.correct, false);
    const completion = await request('/lessons/complete', input);
    assert.equal(completion.status, 200);
    assert.equal(completion.body.earnedXp, 5);
    const practice = await request('/lessons/complete', {...input, completionId: secondStart.body.sessionId});
    assert.equal(practice.status, 200);
    assert.equal(practice.body.earnedXp, 0);
    published = false;
    assert.deepEqual((await request('/lessons/complete', input)).body, completion.body);
    await pool.query("INSERT INTO study_days(account_id,study_date) VALUES($1,CURRENT_DATE+1) ON CONFLICT DO NOTHING", [accountId]);
    assert.equal((await request('/gamification')).status, 200);
    assert.equal((await pool.query('SELECT 1 FROM study_days WHERE account_id=$1 AND study_date=CURRENT_DATE+1', [accountId])).rowCount, 1);
    const other = await request('/auth/register', {fullName: 'Other Learner', email: 'other@example.invalid', password: 'Test-password-123!'});
    token = other.body.sessionToken;
    assert.notDeepEqual((await request('/lessons/complete', input)).body, completion.body);
  });
