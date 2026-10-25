import test from 'node:test';
import assert from 'node:assert/strict';
import {createBoboTutor, BoboError} from './bobo_service.js';

const content = {
  roots: ['cells'],
  nodes: {
    cells: {
      id: 'cells',
      question: 'What are cells?',
      content: 'Cells are small living units.',
      children: [],
      lessonCount: 1,
      exercises: [{
        type: 'singleChoice',
        prompt: 'Which is a cell?',
        options: ['cell', 'rock'],
        correctAnswers: ['cell'],
        explanation: 'A cell is a living unit.',
      }],
    },
  },
};

function createPool({usageRowCount = 1} = {}) {
  const queries = [];
  return {
    queries,
    async query(sql, params = []) {
      queries.push({sql, params});
      if (sql.includes('SELECT preferred_language')) {
        return {rowCount: 1, rows: [{preferred_language: 'en'}]};
      }
      if (sql.includes('FROM lesson_progress')) return {rowCount: 0, rows: []};
      if (sql.includes('INSERT INTO bobo_daily_usage')) {
        return {rowCount: usageRowCount, rows: usageRowCount ? [{request_count: 1}] : []};
      }
      return {rowCount: 1, rows: []};
    },
  };
}

const request = {
  topicId: 'cells',
  lessonId: 'lesson-1',
  exerciseIndex: 0,
  studentAnswer: 'rock',
  answerSubmitted: true,
  answerCorrect: false,
  message: 'Why is a cell alive?',
  history: [],
};

test('Bobo sends server-loaded lesson and account language context to Responses API', async () => {
  const pool = createPool();
  let providerBody;
  const tutor = createBoboTutor({
    pool,
    getLessonContent: () => content,
    apiKey: 'server-only-test-key',
    enabled: true,
    fetchImpl: async (_url, options) => {
      providerBody = JSON.parse(options.body);
      return {
        ok: true,
        async json() {
          return {
            output_text: 'A cell is alive because it carries out processes such as using energy.',
            usage: {input_tokens: 120, output_tokens: 24},
          };
        },
      };
    },
  });

  const result = await tutor.reply('account-id', request);

  assert.match(providerBody.input[0].content, /What are cells\?/);
  assert.match(providerBody.input[0].content, /A cell is a living unit/);
  assert.equal(providerBody.store, false);
  assert.equal(providerBody.model, 'gpt-5.6-luna');
  assert.equal(result.reply, 'A cell is alive because it carries out processes such as using energy.');
  assert.equal(result.remainingToday, 19);
  assert.equal(result.usage.inputTokens, 120);
  assert.doesNotMatch(JSON.stringify(result), /server-only-test-key/);
  assert.ok(pool.queries.some(({sql}) => sql.includes('UPDATE bobo_daily_usage')));
});

test('Bobo rejects unavailable features and invalid lesson context before calling provider', async () => {
  let providerCalls = 0;
  const disabled = createBoboTutor({
    pool: createPool(),
    getLessonContent: () => content,
    apiKey: 'test-key',
    enabled: false,
    fetchImpl: async () => { providerCalls++; },
  });
  await assert.rejects(disabled.reply('account-id', request), (error) =>
    error instanceof BoboError && error.code === 'disabled');

  const tutor = createBoboTutor({
    pool: createPool(),
    getLessonContent: () => content,
    apiKey: 'test-key',
    enabled: true,
    fetchImpl: async () => { providerCalls++; },
  });
  await assert.rejects(tutor.reply('account-id', {...request, lessonId: 'lesson-2'}), (error) =>
    error instanceof BoboError && error.code === 'invalid_context');
  await assert.rejects(tutor.reply('account-id', {...request, message: ' '.repeat(3)}), (error) =>
    error instanceof BoboError && error.code === 'invalid_message');
  assert.equal(providerCalls, 0);
});

test('Bobo enforces the per-account daily reservation limit', async () => {
  let providerCalls = 0;
  const tutor = createBoboTutor({
    pool: createPool({usageRowCount: 0}),
    getLessonContent: () => content,
    apiKey: 'test-key',
    enabled: true,
    fetchImpl: async () => { providerCalls++; },
  });
  await assert.rejects(tutor.reply('account-id', request), (error) =>
    error instanceof BoboError && error.code === 'daily_limit');
  assert.equal(providerCalls, 0);
});
