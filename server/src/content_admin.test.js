import test from 'node:test';
import assert from 'node:assert/strict';
import {listContentLessons} from './content_admin.js';

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
