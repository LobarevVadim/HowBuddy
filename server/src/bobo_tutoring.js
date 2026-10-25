export const TUTORING_STATES = [
  'diagnosing', 'guiding', 'hinting', 'correctingMisconception',
  'explaining', 'checkingUnderstanding', 'completed',
];

export const TEACHING_MODES = [
  'socratic', 'progressiveHint', 'conceptExplanation', 'misconceptionCorrection',
  'deeperExploration', 'example', 'quiz',
];

export const TEACHING_ACTIONS = new Set([
  'giveHint', 'guidingQuestion', 'simplify', 'lost', 'explain', 'example',
  'deeper', 'quiz', 'whyWrong', 'helpUnderstand', 'anotherExplanation',
]);

const ACTION_PLANS = {
  giveHint: {mode: 'progressiveHint', state: 'hinting', level: 1},
  guidingQuestion: {mode: 'socratic', state: 'guiding', level: 1},
  simplify: {mode: 'conceptExplanation', state: 'explaining', level: 2},
  lost: {mode: 'conceptExplanation', state: 'explaining', level: 3},
  explain: {mode: 'conceptExplanation', state: 'explaining', level: 4},
  example: {mode: 'example', state: 'guiding', level: 1},
  deeper: {mode: 'deeperExploration', state: 'guiding', level: 1},
  quiz: {mode: 'quiz', state: 'diagnosing', level: 0},
  whyWrong: {mode: 'misconceptionCorrection', state: 'correctingMisconception', level: 2},
  helpUnderstand: {mode: 'socratic', state: 'diagnosing', level: 1},
  anotherExplanation: {mode: 'conceptExplanation', state: 'explaining', level: 3},
};

export function createTutoringPlan({
  exerciseKey,
  answerSubmitted = false,
  answerCorrect = null,
  previousState = {},
  action = null,
}) {
  const sameExercise = exerciseKey !== null && previousState.exerciseKey === exerciseKey;
  const previousLevel = sameExercise && Number.isInteger(previousState.hintLevel)
    ? Math.max(0, Math.min(4, previousState.hintLevel))
    : 0;
  const previousStatus = sameExercise && TUTORING_STATES.includes(previousState.state)
    ? previousState.state
    : 'diagnosing';
  const hasUnansweredExercise = exerciseKey !== null && !answerSubmitted;

  if (action && !TEACHING_ACTIONS.has(action)) throw new TypeError('invalid_teaching_action');
  let plan;
  if (action) {
    plan = {...ACTION_PLANS[action]};
  } else if (hasUnansweredExercise) {
    plan = {
      mode: previousLevel >= 3 ? 'conceptExplanation' : 'socratic',
      state: previousLevel === 0 ? 'diagnosing' : 'guiding',
      level: Math.min(4, previousLevel + 1),
    };
  } else if (answerSubmitted && answerCorrect === false) {
    plan = {mode: 'misconceptionCorrection', state: 'correctingMisconception', level: 2};
  } else if (answerSubmitted && answerCorrect === true) {
    plan = {mode: 'conceptExplanation', state: 'checkingUnderstanding', level: 0};
  } else {
    plan = {mode: 'conceptExplanation', state: 'explaining', level: 0};
  }

  // An explicit exercise explanation request may reveal the answer; otherwise
  // unanswered exercises remain in a guided mode with gradual hinting.
  if (hasUnansweredExercise && !['explain', 'lost'].includes(action)) {
    plan.level = Math.min(4, Math.max(previousLevel, plan.level));
    if (plan.level >= 4 && !action) {
      plan.mode = 'conceptExplanation';
      plan.state = 'explaining';
    }
  }

  return {
    exerciseKey,
    mode: plan.mode,
    state: plan.state,
    hintLevel: plan.level,
    previousHintLevel: previousLevel,
    previousState: previousStatus,
    answerSubmitted,
    answerCorrect,
    action,
    allowDirectAnswer: !hasUnansweredExercise || ['explain', 'lost'].includes(action) ||
      (!action && plan.level >= 4 && previousLevel >= 3),
  };
}

export function tutoringDirective(plan) {
  const actionGuidance = {
    giveHint: 'Give one progressive hint, not the final answer.',
    guidingQuestion: 'Ask one targeted question that guides the learner to the next reasoning step.',
    simplify: 'Explain in simpler language with small steps; do not force a question.',
    lost: 'Assume the learner is stuck: explain clearly and concretely, then offer one manageable next step.',
    explain: 'Give the requested direct explanation. For an unanswered exercise, explain the answer too.',
    example: 'Use a concrete example or analogy that clarifies the idea.',
    deeper: 'Explore mechanisms and scientific nuance at a more advanced level.',
    quiz: 'Ask one short recall or application question about the lesson, not the active exercise answer.',
    whyWrong: 'Use the backend-graded response to explain the misconception gently and show the correct reasoning.',
    helpUnderstand: 'Find the confusing reasoning step with one gentle, specific question.',
    anotherExplanation: 'Rephrase using a genuinely different explanation or analogy; do not repeat prior wording.',
  };
  const base = plan.action ? actionGuidance[plan.action] : plan.exerciseKey && !plan.answerSubmitted
    ? `Use ${plan.state} mode at hint level ${plan.hintLevel}. ${plan.allowDirectAnswer ? 'Provide a clear direct explanation now.' : 'Guide the learner without revealing the answer.'}`
    : plan.answerSubmitted && plan.answerCorrect === false
      ? 'Correct the misconception using the backend-graded response; give a small correction and one check-in.'
      : plan.answerSubmitted && plan.answerCorrect === true
        ? 'Briefly reinforce the reasoning and check understanding only if useful.'
        : 'Answer direct biology questions clearly; use an optional comprehension check only when useful.';
  return `${base} Never change the app's grading or lesson completion.`;
}

export function validateTutorOutput(value, plan) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  if (typeof value.message !== 'string' || !value.message.trim() || value.message.length > 2000) return null;
  if (!TEACHING_MODES.includes(value.teachingMode) || !TUTORING_STATES.includes(value.tutoringState)) return null;
  if (!Number.isInteger(value.hintLevel) || value.hintLevel < 0 || value.hintLevel > 4) return null;
  for (const key of ['misconceptionDetected', 'understandingDemonstrated', 'shouldReturnToExercise', 'directExplanationRequested']) {
    if (typeof value[key] !== 'boolean') return null;
  }

  const unanswered = plan.exerciseKey !== null && !plan.answerSubmitted;
  const allowDirectAnswer = plan.allowDirectAnswer || value.directExplanationRequested;
  const hintLevel = unanswered
    ? Math.max(plan.previousHintLevel, Math.min(plan.hintLevel, value.hintLevel))
    : value.hintLevel;
  return {
    message: value.message.trim(),
    teachingMode: unanswered && !allowDirectAnswer ? plan.mode : value.teachingMode,
    tutoringState: unanswered && !allowDirectAnswer
      ? (value.tutoringState === 'completed' ? plan.state : value.tutoringState)
      : value.tutoringState,
    hintLevel,
    misconceptionDetected: value.misconceptionDetected,
    // This is a conversational signal only, never stored as verified mastery.
    understandingDemonstrated: value.understandingDemonstrated,
    shouldReturnToExercise: value.shouldReturnToExercise,
  };
}

export function tutorStateForStorage(output, plan) {
  return {
    exerciseKey: plan.exerciseKey,
    mode: output.teachingMode,
    state: output.tutoringState,
    hintLevel: Math.max(plan.previousHintLevel, Math.min(4, output.hintLevel)),
    understandingSignal: output.understandingDemonstrated,
  };
}
