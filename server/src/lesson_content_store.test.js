import test from 'node:test';
import assert from 'node:assert/strict';
import {
  LESSON_LANGUAGES,
  ensureLessonContentSchema,
  getLessonContent,
  loadLessonContent,
  validateLessonContent,
} from './lesson_content_store.js';

function normalizedPool({exists = true} = {}) {
  const requestedLanguages = [];
  return {
    requestedLanguages,
    async query(sql, params = []) {
      if (sql.includes('SELECT EXISTS (SELECT 1 FROM content_topics)')) {
        return {rowCount: 1, rows: [{exists}]};
      }
      if (sql.includes('FROM content_tree_roots')) {
        requestedLanguages.push(params[0]);
        return {rowCount: 1, rows: [{topic_id: `${params[0]}-root`} ]};
      }
      if (sql.includes('SELECT t.topic_id, t.metadata')) {
        return {rowCount: params[0].length, rows: params[0].map((language) => ({
          topic_id: `${language}-root`,
          metadata: {},
          question: `Question ${language}`,
          tree_data: {parentId: null, level: 1, children: [], lessonCount: 1, extraLessons: [], metadata: {}},
          language_code: language,
        }))};
      }
      if (sql.includes('FROM content_lessons l')) return {rowCount: 0, rows: []};
      if (sql.includes('FROM content_exercises')) return {rowCount: 0, rows: []};
      throw new Error(`Unexpected SQL in content-store test: ${sql}`);
    },
  };
}

test('loads published normalized content in English by default and localized content on demand', async () => {
  assert.deepEqual(Object.keys(LESSON_LANGUAGES), ['en', 'fr', 'hi', 'es', 'ru']);
  const pool = normalizedPool();
  const english = await loadLessonContent(pool, ['en']);
  assert.deepEqual(pool.requestedLanguages, ['en']);
  assert.equal(getLessonContent(english, 'en').nodes['en-root'].question, 'Question en');
  assert.equal(getLessonContent(english, 'unsupported').nodes['en-root'].question, 'Question en');

  const french = await loadLessonContent(pool, ['fr']);
  assert.deepEqual(pool.requestedLanguages, ['en', 'fr', 'en']);
  assert.equal(getLessonContent(french, 'fr').nodes['fr-root'].question, 'Question fr');
  assert.equal(getLessonContent(french, 'en').nodes['en-root'].question, 'Question en');
});

test('normalized content must exist before the API serves lesson data', async () => {
  await assert.rejects(() => loadLessonContent(normalizedPool({exists: false}), ['en']), /Normalized lesson content is empty/);
});

test('schema initializer reads and executes the content SQL file', async () => {
  let executedSql = '';
  await ensureLessonContentSchema({query: async (sql) => { executedSql = sql; }});
  assert.match(executedSql, /CREATE TABLE IF NOT EXISTS content_topics/);
});

test('invalid lesson content is rejected', () => {
  assert.throws(() => validateLessonContent({roots: ['missing'], nodes: {}}, 'en'));
});
