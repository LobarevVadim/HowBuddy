import test from 'node:test';
import assert from 'node:assert/strict';
import {createTutoringPlan, tutorStateForStorage, validateTutorOutput} from './bobo_tutoring.js';

const output = (overrides = {}) => ({
  message: 'What do you already know about this process?',
  teachingMode: 'socratic',
  tutoringState: 'guiding',
  hintLevel: 1,
  misconceptionDetected: false,
  understandingDemonstrated: false,
  shouldReturnToExercise: false,
  directExplanationRequested: false,
  ...overrides,
});

test('unanswered exercise begins diagnostically and advances hint level across turns', () => {
  const first = createTutoringPlan({exerciseKey: 'lesson:1'});
  assert.equal(first.state, 'diagnosing');
  assert.equal(first.hintLevel, 1);
  const saved = tutorStateForStorage(output(), first);
  const next = createTutoringPlan({exerciseKey: 'lesson:1', previousState: saved});
  assert.equal(next.state, 'guiding');
  assert.equal(next.hintLevel, 2);
});

test('switching exercises resets progression', () => {
  const plan = createTutoringPlan({
    exerciseKey: 'lesson:2',
    previousState: {exerciseKey: 'lesson:1', hintLevel: 3, state: 'hinting'},
  });
  assert.equal(plan.hintLevel, 1);
  assert.equal(plan.previousState, 'diagnosing');
});

test('hint progression caps at level four and opens an explanation when stuck', () => {
  const plan = createTutoringPlan({
    exerciseKey: 'lesson:1',
    previousState: {exerciseKey: 'lesson:1', hintLevel: 3, state: 'hinting'},
  });
  assert.equal(plan.hintLevel, 4);
  assert.equal(plan.mode, 'conceptExplanation');
  assert.equal(plan.allowDirectAnswer, true);
});

test('clear direct explanation request in typed message permits explanation', () => {
  const plan = createTutoringPlan({exerciseKey: 'lesson:1'});
  const validated = validateTutorOutput(output({
    message: 'The left ventricle must pump throughout the body.',
    teachingMode: 'conceptExplanation',
    tutoringState: 'explaining',
    directExplanationRequested: true,
  }), plan);
  assert.equal(validated.teachingMode, 'conceptExplanation');
});

test('explicit explain action permits direct answer on unanswered exercise', () => {
  const plan = createTutoringPlan({exerciseKey: 'lesson:1', action: 'explain'});
  assert.equal(plan.allowDirectAnswer, true);
  assert.equal(plan.hintLevel, 4);
});

test('submitted wrong answer selects misconception correction from trusted grade', () => {
  const plan = createTutoringPlan({exerciseKey: 'lesson:1', answerSubmitted: true, answerCorrect: false});
  assert.equal(plan.mode, 'misconceptionCorrection');
  assert.equal(plan.state, 'correctingMisconception');
});

test('submitted correct answer transitions to a concise understanding check', () => {
  const plan = createTutoringPlan({exerciseKey: 'lesson:1', answerSubmitted: true, answerCorrect: true});
  assert.equal(plan.state, 'checkingUnderstanding');
});

test('lesson mode supports direct explanations and deeper exploration', () => {
  assert.equal(createTutoringPlan({exerciseKey: null}).mode, 'conceptExplanation');
  assert.equal(createTutoringPlan({exerciseKey: null, action: 'deeper'}).mode, 'deeperExploration');
});

test('invalid model output is rejected and response hint cannot exceed server plan', () => {
  const plan = createTutoringPlan({exerciseKey: 'lesson:1'});
  assert.equal(validateTutorOutput({...output(), hintLevel: 4}, plan).hintLevel, 1);
  assert.equal(validateTutorOutput({...output(), tutoringState: 'untrusted'}, plan), null);
  assert.equal(validateTutorOutput({...output(), message: ''}, plan), null);
});

test('model cannot mark an unanswered exercise complete', () => {
  const plan = createTutoringPlan({exerciseKey: 'lesson:1'});
  const validated = validateTutorOutput(output({tutoringState: 'completed'}), plan);
  assert.equal(validated.tutoringState, 'diagnosing');
});

test('client cannot select an unsupported teaching action', () => {
  assert.throws(() => createTutoringPlan({exerciseKey: null, action: 'revealAnswer'}), /invalid_teaching_action/);
});
