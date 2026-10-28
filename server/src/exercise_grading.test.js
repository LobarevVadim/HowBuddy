import test from 'node:test';
import assert from 'node:assert/strict';
import {gradeResponse, gradeAnswer} from './exercise_grading.js';

for (const type of ['singleChoice', 'trueFalse', 'spotTheMistake', 'shortAnswer']) {
  test(`${type}: authoritative normalized correct and incorrect responses`, () => {
    const exercise = {type, options: ['Cell', 'Rock'], correctAnswers: ['Cell']};
    assert.deepEqual(gradeResponse(exercise, ' cell '), {submitted: true, correct: true});
    assert.deepEqual(gradeResponse(exercise, 'Rock'), {submitted: true, correct: false});
  });
}
for (const type of ['orderSteps', 'buildTheProcess', 'fillInTheBlank']) {
  test(`${type}: ordered values preserve embedded punctuation`, () => {
    const exercise = {type, options: ['A → B', 'C | D'], correctOrder: ['A → B', 'C | D']};
    assert.equal(gradeResponse(exercise, ['A → B', 'C | D']).correct, true);
    assert.equal(gradeResponse(exercise, ['C | D', 'A → B']).correct, false);
    assert.equal(gradeResponse(exercise, ['A → B']).submitted, false);
  });
}
for (const type of ['matching', 'categorization', 'causeAndEffect', 'compareAndContrast']) {
  test(`${type}: map responses preserve colons and semicolons`, () => {
    const exercise = {type, pairs: [{left: 'A: B', right: 'C; D'}]};
    assert.deepEqual(gradeResponse(exercise, {'A: B': 'C; D'}), {submitted: true, correct: true});
    assert.equal(gradeResponse(exercise, {}).submitted, false);
    assert.equal(gradeResponse(exercise, {'A: B': 'wrong'}).correct, false);
  });
}
test('multipleSelect preserves comma-bearing options and rejects duplicates/unknown options', () => {
  const exercise = {type: 'multipleSelect', options: ['Cells, living units', 'Rock'], correctAnswers: ['Cells, living units']};
  assert.equal(gradeResponse(exercise, ['Cells, living units']).correct, true);
  assert.equal(gradeResponse(exercise, ['Rock']).correct, false);
  assert.equal(gradeResponse(exercise, ['Rock', 'Rock']).submitted, false);
  assert.equal(gradeResponse(exercise, ['unknown']).submitted, false);
});
test('legacy strings remain supported for unambiguous existing clients', () => {
  assert.equal(gradeAnswer({type: 'orderSteps', options: ['A', 'B'], correctOrder: ['A', 'B']}, 'A → B').correct, true);
});
