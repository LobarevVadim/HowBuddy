import test from 'node:test';
import assert from 'node:assert/strict';
import {
  createGoogleTranslationClient,
  translateExercisePayload,
  translateExerciseToAllLanguages,
  translateLessonToAllLanguages,
  translateTopicToAllLanguages,
} from './google_translation.js';

test('Google Basic Translation sends text to the configured API and maps returned strings', async () => {
  let request;
  const client = createGoogleTranslationClient({
    apiKey: 'test-secret',
    fetchImpl: async (url, options) => {
      request = {url: new URL(url), options, body: JSON.parse(options.body)};
      return {ok: true, json: async () => ({data: {translations: [
        {translatedText: 'Bonjour'},
      ]}})};
    },
  });
  const result = await client.translateStrings(['Hello', '', ''], 'en', 'fr');
  assert.deepEqual(result, ['Bonjour', '', '']);
  assert.equal(request.url.origin + request.url.pathname, 'https://translation.googleapis.com/language/translate/v2');
  assert.equal(request.url.searchParams.get('key'), 'test-secret');
  assert.deepEqual(request.body.q, ['Hello']);
  assert.equal(request.body.source, 'en');
  assert.equal(request.body.target, 'fr');
  assert.equal(request.options.method, 'POST');
});

test('missing Google credentials fail with an actionable setup message', async () => {
  const client = createGoogleTranslationClient({apiKey: '', fetchImpl: async () => assert.fail('must not call Google')});
  await assert.rejects(() => client.translateStrings(['Hello'], 'en', 'fr'), /GOOGLE_TRANSLATE_API_KEY/);
});

test('exercise translation preserves type and identifiers while translating answers and consequence keys', async () => {
  const payload = {
    type: 'singleChoice',
    id: 'exercise-1',
    prompt: 'Which organ pumps blood?',
    options: ['heart', 'lung'],
    correctAnswers: ['heart'],
    consequences: {'heart': 'Blood moves through the body.', 'lung': 'The lungs exchange gases.'},
    explanation: 'The heart pumps blood.',
  };
  const translated = await translateExercisePayload(payload, 'en', 'fr', async (strings) => strings.map((value) => `FR:${value}`));
  assert.equal(translated.type, 'singleChoice');
  assert.equal(translated.id, 'exercise-1');
  assert.equal(translated.options[0], 'FR:heart');
  assert.equal(translated.correctAnswers[0], 'FR:heart');
  assert.equal(translated.consequences['FR:heart'], 'FR:Blood moves through the body.');
  assert.equal(translated.explanation, 'FR:The heart pumps blood.');
});

test('translate-to-all keeps the selected source and requests each other language', async () => {
  const calls = [];
  const lesson = await translateLessonToAllLanguages({
    language: 'en', title: 'Lesson title', content: 'Lesson text',
    translateStrings: async (strings, source, target) => {
      calls.push({source, target});
      return strings.map((value) => `${target}:${value}`);
    },
  });
  assert.deepEqual(Object.keys(lesson).sort(), ['en', 'es', 'fr', 'hi', 'ru']);
  assert.equal(lesson.en.title, 'Lesson title');
  assert.equal(lesson.fr.content, 'fr:Lesson text');
  assert.equal(calls.length, 4);
  assert.deepEqual(calls.map((call) => call.target).sort(), ['es', 'fr', 'hi', 'ru']);

  const exercises = await translateExerciseToAllLanguages({
    language: 'fr', payload: {type: 'shortAnswer', prompt: 'Question', correctAnswers: ['cell'], explanation: 'Because.'},
    translateStrings: async (strings, source, target) => strings.map((value) => `${source}-${target}:${value}`),
  });
  assert.equal(exercises.fr.prompt, 'Question');
  assert.equal(exercises.en.correctAnswers[0], 'fr-en:cell');
  assert.equal(exercises.en.type, 'shortAnswer');
});

test('Google HTTP errors never expose the API key', async () => {
  const client = createGoogleTranslationClient({
    apiKey: 'do-not-print-this',
    fetchImpl: async () => ({ok: false, status: 403}),
  });
  await assert.rejects(
    () => client.translateStrings(['hello'], 'en', 'ru'),
    (error) => error.message.includes('HTTP 403') && !error.message.includes('do-not-print-this'),
  );
});

test('whole-topic translation batches learner-facing text and preserves structure across all languages', async () => {
  const topic = {
    id: 'brain-topic',
    question: 'Can you survive with half your brain?',
    treeData: {children: ['child-topic'], lessonCount: 1},
    lessons: [{
      id: 'lesson-id', lessonNumber: 1, title: 'Brain basics', content: 'The brain has two halves.',
      exercises: [{
        id: 'exercise-id', position: 0, type: 'singleChoice',
        payload: {
          type: 'singleChoice', id: 'exercise-id', prompt: 'Which organ controls thought?',
          options: ['brain', 'lung'], correctAnswers: ['brain'], explanation: 'The brain processes thoughts.',
        },
      }],
    }],
  };
  const calls = [];
  const translations = await translateTopicToAllLanguages({
    language: 'en',
    topic,
    translateStrings: async (strings, source, target) => {
      calls.push({strings, source, target});
      return strings.map((value) => `${target}:${value}`);
    },
  });
  assert.deepEqual(Object.keys(translations).sort(), ['en', 'es', 'fr', 'hi', 'ru']);
  assert.equal(translations.en, topic);
  assert.equal(translations.fr.question, 'fr:Can you survive with half your brain?');
  assert.equal(translations.fr.lessons[0].content, 'fr:The brain has two halves.');
  assert.equal(translations.fr.lessons[0].exercises[0].payload.type, 'singleChoice');
  assert.equal(translations.fr.lessons[0].exercises[0].payload.correctAnswers[0], 'fr:brain');
  assert.equal(translations.fr.lessons[0].exercises[0].payload.id, 'exercise-id');
  assert.equal(calls.length, 4);
  assert.equal(calls.every((call) => call.strings.length === 8), true);
});
