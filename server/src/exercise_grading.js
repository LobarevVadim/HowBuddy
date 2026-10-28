const normalize = (value) => String(value).trim().toLowerCase().replace(/\s+/g, ' ');
const invalid = () => ({submitted: false, correct: null});
const strings = (value) => Array.isArray(value) && value.length <= 30 && value.every((part) => typeof part === 'string' && part.trim() && part.length <= 2000);
const same = (left, right) => JSON.stringify(left) === JSON.stringify(right);

// This is the single grading rule set for typed app submissions, stored session
// answers and the legacy textual tutor API. Transport separators are not rules.
export function gradeResponse(exercise, response) {
  const correct = exercise.correctAnswers ?? [];
  const order = exercise.correctOrder ?? [];
  const options = (exercise.options ?? []).map(normalize);
  switch (exercise.type) {
    case 'singleChoice': case 'trueFalse': case 'spotTheMistake':
    case 'scenarioBasedDecision': case 'prediction':
      if (typeof response !== 'string' || !options.includes(normalize(response))) return invalid();
      return {submitted: true, correct: correct.length ? correct.some((value) => normalize(value) === normalize(response)) : null};
    case 'shortAnswer':
      if (typeof response !== 'string' || !response.trim() || response.length > 2000) return invalid();
      return {submitted: true, correct: correct.length ? correct.some((value) => normalize(value) === normalize(response)) : null};
    case 'multipleSelect': {
      if (!strings(response) || !response.length) return invalid();
      const selected = response.map(normalize);
      if (new Set(selected).size !== selected.length || !selected.every((value) => options.includes(value))) return invalid();
      return {submitted: true, correct: same([...selected].sort(), correct.map(normalize).sort())};
    }
    case 'orderSteps': case 'buildTheProcess': case 'fillInTheBlank': {
      if (!strings(response) || response.length !== order.length || !order.length) return invalid();
      const selected = response.map(normalize);
      if (exercise.type !== 'fillInTheBlank' && options.length && !selected.every((value) => options.includes(value))) return invalid();
      return {submitted: true, correct: same(selected, order.map(normalize))};
    }
    case 'matching': case 'categorization': case 'causeAndEffect': case 'compareAndContrast': case 'diagramLabeling': {
      if (!response || typeof response !== 'object' || Array.isArray(response)) return invalid();
      const pairs = exercise.type === 'diagramLabeling' ? Object.entries(exercise.correctLabels ?? {})
        : (exercise.pairs ?? []).map((pair) => [pair.left, pair.right]);
      const entries = Object.entries(response);
      if (!pairs.length || entries.length !== pairs.length || entries.some(([key, value]) => key.length > 2000 || typeof value !== 'string' || !value.trim() || value.length > 2000)) return invalid();
      const selected = new Map(entries.map(([key, value]) => [normalize(key), normalize(value)]));
      if (selected.size !== pairs.length || !pairs.every(([key]) => selected.has(normalize(key)))) return invalid();
      return {submitted: true, correct: pairs.every(([key, value]) => selected.get(normalize(key)) === normalize(value))};
    }
    default: return invalid();
  }
}

export function legacyResponse(exercise, answer) {
  if (typeof answer !== 'string') return null;
  switch (exercise.type) {
    case 'multipleSelect': return answer.split(',').map((part) => part.trim()).filter(Boolean);
    case 'fillInTheBlank': return answer.split('|').map((part) => part.trim());
    case 'orderSteps': case 'buildTheProcess': return answer.split(/\s*\u2192\s*/u).map((part) => part.trim());
    case 'matching': case 'categorization': case 'causeAndEffect': case 'compareAndContrast': case 'diagramLabeling':
      return Object.fromEntries(answer.split(';').map((part) => {
        const separator = part.indexOf(':');
        return separator < 0 ? ['', ''] : [part.slice(0, separator).trim(), part.slice(separator + 1).trim()];
      }));
    default: return answer;
  }
}
export const gradeAnswer = (exercise, answer) => gradeResponse(exercise, legacyResponse(exercise, answer));
export const isCompleteAttempt = (exercise, answer) => gradeAnswer(exercise, answer).submitted;
