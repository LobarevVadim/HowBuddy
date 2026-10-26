import test from 'node:test';
import assert from 'node:assert/strict';
import {
  LESSON_LANGUAGES,
  ensureLessonContentSchema,
  getLessonContent,
  loadLessonContent,
  validateLessonContent,
} from './lesson_content_store.js';

function normalizedPool({exists = true, publishedLessons = []} = {}) {
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
        const rows = params[0].flatMap((language) => {
          const root = {
            topic_id: `${language}-root`,
            metadata: {},
            question: `Question ${language}`,
            tree_data: {parentId: null, level: 1, children: [], lessonCount: 7, extraLessons: [], metadata: {}},
            language_code: language,
          };
          const materialIds = language === 'en'
            ? [...new Set(publishedLessons.map((lesson) => lesson.material_topic_id))]
                .filter((id) => id !== root.topic_id)
            : [];
          return [root, ...materialIds.map((topic_id) => ({
            topic_id,
            metadata: {},
            question: `Lesson ${topic_id}`,
            tree_data: {parentId: null, level: 2, children: [], lessonCount: 1, extraLessons: [], metadata: {}},
            language_code: language,
          }))];
        });
        return {rowCount: rows.length, rows};
      }
      if (sql.includes('FROM content_lessons l')) return {rowCount: publishedLessons.length, rows: publishedLessons};
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

test('tree lesson count and links follow published lessons instead of stale planned counts', async () => {
  const lessons = [1, 2, 3, 8].map((lesson_number) => ({
    id: `lesson-${lesson_number}`,
    topic_id: 'en-root',
    lesson_number,
    material_topic_id: lesson_number === 1 ? 'en-root' : `material-${lesson_number}`,
    title: `Lesson ${lesson_number}`,
    content: `Content ${lesson_number}`,
    language_code: 'en',
  }));
  const content = await loadLessonContent(normalizedPool({publishedLessons: lessons}), ['en']);
  const root = getLessonContent(content, 'en').nodes['en-root'];
  assert.equal(root.lessonCount, 4);
  assert.deepEqual(root.extraLessons, ['material-2', 'material-3', 'material-8']);
});

test('schema initializer reads and executes the content SQL file', async () => {
  let executedSql = '';
  await ensureLessonContentSchema({query: async (sql) => { executedSql = sql; }});
  assert.match(executedSql, /CREATE TABLE IF NOT EXISTS content_topics/);
});

test('invalid lesson content is rejected', () => {
  assert.throws(() => validateLessonContent({roots: ['missing'], nodes: {}}, 'en'));
});
