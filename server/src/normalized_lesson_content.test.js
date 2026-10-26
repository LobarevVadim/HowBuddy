import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {EXERCISE_TYPES, validateExercisePayload} from './normalized_lesson_content.js';

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

test('content schema declares each lesson draft column once', () => {
  const schema = readFileSync(new URL('../content_schema.sql', import.meta.url), 'utf8');
  const draftTable = schema.match(/CREATE TABLE IF NOT EXISTS content_lesson_drafts \(([\s\S]*?)\n\);/);
  assert.ok(draftTable, 'lesson draft table should be declared');
  const columns = draftTable[1].split('\n')
    .map((line) => line.trim().match(/^([a-z_]+)\s/))
    .filter(Boolean)
    .map((match) => match[1]);
  assert.equal(new Set(columns).size, columns.length, 'draft table must not repeat a column');
});
