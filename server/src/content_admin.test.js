import test from 'node:test';
import assert from 'node:assert/strict';
import {
  listContentLessons,
  synchronizeTopicTranslations,
} from './content_admin.js';

test('content editor lists published lessons in learner-visible order despite sparse stored numbers', async () => {
  const pool = {
    async query() {
      return {
        rowCount: 4,
        rows: [1, 2, 3, 8].map((lessonNumber) => ({
          id: `lesson-${lessonNumber}`,
          topic_id: 'brain',
          lesson_number: lessonNumber,
          material_topic_id: lessonNumber === 1 ? 'brain' : `brain-${lessonNumber}`,
          title: `Lesson ${lessonNumber}`,
          content: `Content ${lessonNumber}`,
          status: 'published',
          exercise_count: 1,
        })),
      };
    },
  };
  const lessons = await listContentLessons(pool, 'brain', 'en');
  assert.deepEqual(lessons.map((lesson) => lesson.lessonNumber), [1, 2, 3, 4]);
  assert.deepEqual(lessons.map((lesson) => lesson.id), [
    'lesson-1', 'lesson-2', 'lesson-3', 'lesson-8',
  ]);
});

test('topic synchronization deletes target-only lessons and exercises while retaining revision snapshots', async () => {
  const calls = [];
  const client = {
    async query(sql, params = []) {
      calls.push({sql, params});
      if (sql === 'BEGIN' || sql === 'COMMIT' || sql === 'ROLLBACK') return {rowCount: 0, rows: []};
      if (sql.includes('SELECT topic_id FROM content_topics')) return {rowCount: 1, rows: [{topic_id: 'brain'}]};
      if (sql.includes('SELECT l.id FROM content_lessons l')) return {rowCount: 1, rows: [{id: 'source-lesson'}]};
      if (sql.includes('SELECT tree_data FROM content_topic_translations')) return {rowCount: 1, rows: [{tree_data: {lessonCount: 1, extraLessons: []}}]};
      if (sql.includes('SELECT l.id, tr.material_topic_id, tr.title, tr.content')) {
        return params[1] === 'fr'
          ? {rowCount: 1, rows: [{id: 'fr-only-lesson', material_topic_id: 'fr-only-material', title: 'Old', content: 'Old'}]}
          : {rowCount: 0, rows: []};
      }
      if (sql.includes('SELECT id, exercise_json FROM content_exercises') && params.length === 3) {
        return {rowCount: 1, rows: [{id: `${params[1]}-keep`, exercise_json: {type: 'singleChoice'}}]};
      }
      if (sql.includes('SELECT id, exercise_json FROM content_exercises')) {
        return params[0] === 'fr-only-lesson'
          ? {rowCount: 1, rows: [{id: 'fr-only-exercise', exercise_json: {type: 'singleChoice'}}]}
          : {rowCount: 0, rows: []};
      }
      if (sql.includes('SELECT COALESCE(MAX(revision_number)')) return {rowCount: 1, rows: [{revision: 0}]};
      if (sql.includes('SELECT material_topic_id, title, content FROM content_lesson_translations')) {
        return {rowCount: 1, rows: [{material_topic_id: 'brain', title: 'Old title', content: 'Old content'}]};
      }
      if (sql.includes('SELECT id, position, exercise_json FROM content_exercises')) {
        const lang = params[1];
        return {
          rowCount: lang === 'fr' || lang === 'es' ? 2 : 1,
          rows: [
            {id: `${lang}-keep`, position: 0, exercise_json: {type: 'singleChoice'}},
            ...(lang === 'fr' || lang === 'es'
              ? [{id: `${lang}-extra`, position: 1, exercise_json: {type: 'singleChoice'}}]
              : []),
          ],
        };
      }
      if (sql.includes('SELECT tr.material_topic_id FROM content_lessons l')) {
        return {rowCount: 1, rows: [{material_topic_id: 'brain'}]};
      }
      return {rowCount: 0, rows: []};
    },
    release() {},
  };
  const pool = {connect: async () => client};
  const payload = {
    type: 'singleChoice', prompt: 'Question?', options: ['A', 'B'],
    correctAnswers: ['A'], explanation: 'Explanation.',
  };
  const sourceLesson = {
    id: 'source-lesson', lessonNumber: 1, materialTopicId: 'brain',
    title: 'Lesson', content: 'Content', exercises: [{id: 'source-exercise', position: 0, type: 'singleChoice', payload}],
  };
  const topic = {id: 'brain', level: 1, question: 'Topic?', treeData: {}, lessons: [sourceLesson]};
  const translationsByLanguage = Object.fromEntries(['en', 'fr', 'es', 'hi', 'ru'].map((language) => [
    language,
    {
      question: `${language} topic`,
      lessons: [{...sourceLesson, title: `${language} lesson`, content: `${language} content`, exercises: [
        {...sourceLesson.exercises[0], payload: {...payload, prompt: `${language} question`}},
      ]}],
    },
  ]));

  await synchronizeTopicTranslations(pool, {
    topic, sourceLanguage: 'en', translationsByLanguage, accountId: 'admin-account',
  });

  assert.equal(calls.some(({sql}) => sql.includes('DELETE FROM content_lesson_translations WHERE lesson_id = $1 AND language_code = $2')), true);
  assert.equal(calls.some(({sql}) => sql.includes('DELETE FROM content_exercises WHERE id = $1')), true);
  assert.equal(calls.some(({sql}) => sql.includes('DELETE FROM content_exercises WHERE lesson_id = $1 AND language_code = $2')), true);
  assert.equal(calls.filter(({sql}) => sql.includes('INSERT INTO content_revisions')).length >= 4, true);
  assert.equal(calls.some(({sql}) => sql === 'COMMIT'), true);
});
