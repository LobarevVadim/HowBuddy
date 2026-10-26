import test from 'node:test';
import assert from 'node:assert/strict';
import {
  createGoogleTranslationClient,
  translateExercisePayload,
  translateExerciseToAllLanguages,
  translateLessonToAllLanguages,
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
