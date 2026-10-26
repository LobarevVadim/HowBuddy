import test from 'node:test';
import assert from 'node:assert/strict';
import {createNotificationScheduler, reachableQuestionNodes, slotDue} from './notification_scheduler.js';

function persistentFakePool() {
  const claims = new Set();
  return {
    claims,
    async query() {
      return {rows: [{
        account_id: 'account-1',
        enabled: true,
        curiosity_enabled: true,
        quiet_hours_enabled: true,
        quiet_start_minute: 22 * 60,
        quiet_end_minute: 8 * 60,
        time_zone: 'UTC',
        language: 'en',
        tokens: ['device-token'],
        study_dates: [],
        sent_types: [],
        daily_count: 0,
      }]};
    },
    async connect() {
      return {
        async query(sql, values = []) {
          if (sql.startsWith('SELECT count(*)')) {
            const prefix = `${values[0]}:${values[1]}:`;
            return {rows: [{value: [...claims].filter((claim) => claim.startsWith(prefix)).length}]};
          }
          if (sql.startsWith('INSERT INTO notification_deliveries')) {
            const [account, date, type] = values;
            const key = `${account}:${date}:${type}`;
            if (claims.has(key)) return {rowCount: 0, rows: []};
            claims.add(key);
            return {rowCount: 1, rows: [{id: claims.size}]};
          }
          return {rowCount: 0, rows: []};
        },
        release() {},
      };
    },
  };
}

test('curiosity messages choose among all 39 reachable tree questions', () => {
  const content = {roots: [], nodes: {}};
  for (let rootIndex = 0; rootIndex < 3; rootIndex++) {
    const rootId = `root-${rootIndex}`;
    content.roots.push(rootId);
    content.nodes[rootId] = {id: rootId, question: `Root ${rootIndex}`, children: []};
    for (let branchIndex = 0; branchIndex < 3; branchIndex++) {
      const branchId = `${rootId}-branch-${branchIndex}`;
      content.nodes[rootId].children.push(branchId);
      content.nodes[branchId] = {id: branchId, question: `Branch ${branchIndex}`, children: []};
      for (let leafIndex = 0; leafIndex < 3; leafIndex++) {
        const leafId = `${branchId}-leaf-${leafIndex}`;
        content.nodes[branchId].children.push(leafId);
        content.nodes[leafId] = {id: leafId, question: `Leaf ${leafIndex}`, children: []};
      }
    }
  }
  const questions = reachableQuestionNodes(content);
  assert.equal(questions.length, 39);
  assert.ok(questions.every(({id, question}) => id && question));
});

test('local schedule slots begin at 9 a.m., noon, and 6 p.m.', () => {
  assert.equal(slotDue({hour: 9, minute: 0}), 'morning');
  assert.equal(slotDue({hour: 12, minute: 0}), 'afternoon');
  assert.equal(slotDue({hour: 18, minute: 0}), 'evening');
  assert.equal(slotDue({hour: 9, minute: 20}), null);
});

test('a delivery claim survives a scheduler restart and prevents a second send', async () => {
  const pool = persistentFakePool();
  let sendCount = 0;
  const messaging = {
    async sendEachForMulticast() {
      sendCount++;
      return {successCount: 1, responses: [{success: true}]};
    },
  };
  const getLessonContent = () => ({
    roots: ['heart'],
    nodes: {heart: {id: 'heart', question: 'How does your body work?', children: []}},
  });

  const firstProcess = createNotificationScheduler({pool, messaging, getLessonContent});
  const firstResult = await firstProcess.tick(new Date('2026-10-19T09:05:00Z'));
  firstProcess.stop();

  const restartedProcess = createNotificationScheduler({pool, messaging, getLessonContent});
  const afterRestart = await restartedProcess.tick(new Date('2026-10-19T09:05:00Z'));
  restartedProcess.stop();

  assert.equal(firstResult.sent, 1);
  assert.equal(afterRestart.sent, 0);
  assert.equal(sendCount, 1);
  assert.equal(pool.claims.size, 1);
});
