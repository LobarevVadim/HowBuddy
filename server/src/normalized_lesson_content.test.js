import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {
  EXERCISE_TYPES,
  projectPublishedLessons,
  validateExercisePayload,
} from './normalized_lesson_content.js';

const samples = {
  singleChoice: {options: ['A', 'B'], correctAnswers: ['A']},
  multipleSelect: {options: ['A', 'B'], correctAnswers: ['A']},
  shortAnswer: {correctAnswers: ['cell']},
  orderSteps: {options: ['B', 'A'], correctOrder: ['A', 'B']},
  matching: {options: ['B', 'A'], pairs: [{left: 'a', right: 'A'}, {left: 'b', right: 'B'}]},
  fillInTheBlank: {correctOrder: ['cell'], paragraphParts: ['A ', ' lives.']},
  trueFalse: {options: ['True', 'False'], correctAnswers: ['True']},
  spotTheMistake: {options: ['true', 'false'], correctAnswers: ['false']},
  categorization: {options: ['A', 'B'], pairs: [{left: 'x', right: 'A'}, {left: 'y', right: 'B'}]},
  causeAndEffect: {options: ['A', 'B'], pairs: [{left: 'x', right: 'A'}, {left: 'y', right: 'B'}]},
  compareAndContrast: {categories: ['A only', 'Both', 'B only'], pairs: [{left: 'x', right: 'Both'}, {left: 'y', right: 'A only'}]},
  buildTheProcess: {options: ['A', 'B'], correctOrder: ['A', 'B']},
};

test('the editor and database schema accept all twelve supported interaction types', () => {
  assert.equal(EXERCISE_TYPES.length, 12);
  for (const type of EXERCISE_TYPES) {
    assert.doesNotThrow(() => validateExercisePayload(type, {
      type,
      prompt: 'Question?',
      explanation: 'Explanation.',
      ...samples[type],
    }), type);
  }
});

test('exercise validator rejects a mismatched type and incomplete fill-in blanks', () => {
  assert.throws(() => validateExercisePayload('singleChoice', {
    type: 'multipleSelect', prompt: 'Question?', explanation: 'Because.',
    options: ['A', 'B'], correctAnswers: ['A'],
  }), /selected type/);
  assert.throws(() => validateExercisePayload('fillInTheBlank', {
    type: 'fillInTheBlank', prompt: 'Question?', explanation: 'Because.',
    correctOrder: ['cell'], paragraphParts: ['Only one segment'],
  }), /paragraph segment/);
});

test('published lesson projection ignores legacy numbering gaps and uses dense tree order', () => {
  const projection = projectPublishedLessons([
    {topic_id: 'brain', lesson_number: 1, material_topic_id: 'brain'},
    {topic_id: 'brain', lesson_number: 2, material_topic_id: 'brain-2'},
    {topic_id: 'brain', lesson_number: 3, material_topic_id: 'brain-3'},
    {topic_id: 'brain', lesson_number: 8, material_topic_id: 'brain-8'},
  ]);
  assert.deepEqual(projection.get('brain'), {
    lessonCount: 4,
    extraLessons: ['brain-2', 'brain-3', 'brain-8'],
  });
});

test('content schema removes the obsolete snapshots and draft tables', () => {
  const schema = readFileSync(new URL('../content_schema.sql', import.meta.url), 'utf8');
  assert.doesNotMatch(schema, /CREATE TABLE IF NOT EXISTS lesson_content_by_language/);
  assert.doesNotMatch(schema, /CREATE TABLE IF NOT EXISTS content_(?:lesson|exercise)_drafts/);
  assert.match(schema, /DROP TABLE IF EXISTS public\.content_lesson_drafts/);
  assert.match(schema, /DROP TABLE IF EXISTS public\.content_exercise_drafts/);
  assert.match(schema, /DROP TABLE IF EXISTS public\.lesson_content_by_language/);
  for (const table of schema.matchAll(/CREATE TABLE IF NOT EXISTS ([a-z_]+) \(([\s\S]*?)\n\);/g)) {
    const columns = table[2].split('\n')
      .map((line) => line.match(/^  ([a-z_]+)\s+[A-Z]/i))
      .filter(Boolean)
      .map((match) => match[1]);
    assert.equal(new Set(columns).size, columns.length, `${table[1]} must not repeat a column`);
  }
});
