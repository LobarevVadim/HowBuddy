const API_URL = 'https://translation.googleapis.com/language/translate/v2';
const LANGUAGE_CODES = new Set(['en', 'fr', 'es', 'hi', 'ru']);
const protectedFields = new Set(['type', 'id', 'url', 'src', 'asset', 'assetPath']);
const TRANSLATION_TOKEN = Symbol('translation-token');
const CONSEQUENCE_TOKEN = Symbol('consequence-entries');

export function createGoogleTranslationClient({apiKey, fetchImpl = fetch} = {}) {
  return {
    configured: Boolean(String(apiKey ?? '').trim()),
    async translateStrings(strings, source, target) {
      const key = String(apiKey ?? '').trim();
      if (!key) throw new Error('Google Cloud Translation is not configured. Set GOOGLE_TRANSLATE_API_KEY on the API service.');
      if (!LANGUAGE_CODES.has(source) || !LANGUAGE_CODES.has(target)) {
        throw new Error('Choose a supported translation language.');
      }
      if (source === target) return [...strings];
      const translated = [...strings];
      const pending = strings.map((text, index) => ({text: String(text), index}))
        .filter(({text}) => text.trim().length > 0);
      let offset = 0;
      while (offset < pending.length) {
        const batch = [];
        let batchSize = 0;
        while (offset < pending.length && batch.length < 100) {
          const item = pending[offset];
          const text = item.text;
          if (text.length + batchSize > 20000 && batch.length) break;
          batch.push(item);
          batchSize += text.length;
          offset += 1;
        }
        const url = new URL(API_URL);
        url.searchParams.set('key', key);
        let response;
        try {
          response = await fetchImpl(url, {
            method: 'POST',
            headers: {'content-type': 'application/json; charset=utf-8'},
            body: JSON.stringify({q: batch.map((item) => item.text), source, target, format: 'text'}),
            signal: AbortSignal.timeout(20000),
          });
        } catch (_) {
          throw new Error('Could not reach Google Cloud Translation. Check API deployment and network access.');
        }
        if (!response.ok) {
          throw new Error(`Google Cloud Translation returned HTTP ${response.status}. Check the API key, enabled API, billing, and quotas.`);
        }
        let result;
        try {
          result = await response.json();
        } catch (_) {
          throw new Error('Google Cloud Translation returned an invalid response.');
        }
        const values = result?.data?.translations;
        if (!Array.isArray(values) || values.length !== batch.length ||
            values.some((item) => typeof item?.translatedText !== 'string')) {
          throw new Error('Google Cloud Translation returned an incomplete translation.');
        }
        values.forEach((item, index) => {
          translated[batch[index].index] = item.translatedText;
        });
      }
      return translated;
    },
  };
}

export async function translateLessonToAllLanguages({language, title, content, translateStrings}) {
  validateSourceLanguage(language);
  const translations = {[language]: {title: String(title), content: String(content)}};
  const targets = [...LANGUAGE_CODES].filter((target) => target !== language);
  for (const target of targets) {
    const [translatedTitle, translatedContent] = await translateStrings(
      [String(title), String(content)], language, target);
    translations[target] = {title: translatedTitle, content: translatedContent};
  }
  return translations;
}

export async function translateExerciseToAllLanguages({language, payload, translateStrings}) {
  validateSourceLanguage(language);
  const translations = {[language]: payload};
  const targets = [...LANGUAGE_CODES].filter((target) => target !== language);
  for (const target of targets) {
    translations[target] = await translateExercisePayload(payload, language, target, translateStrings);
  }
  return translations;
}

export async function translateTopicToAllLanguages({language, topic, translateStrings}) {
  validateSourceLanguage(language);
  const exerciseText = new Map();
  const sourceStrings = [String(topic.question ?? '')];
  for (const lesson of topic.lessons ?? []) {
    sourceStrings.push(String(lesson.title ?? ''), String(lesson.content ?? ''));
    for (const exercise of lesson.exercises ?? []) {
      let collected = [];
      await translateExercisePayload(exercise.payload, language, language, async (strings) => {
        collected = strings;
        return strings;
      });
      exerciseText.set(exercise, collected);
      sourceStrings.push(...collected);
    }
  }

  const translations = {[language]: topic};
  const targets = [...LANGUAGE_CODES].filter((target) => target !== language);
  for (const target of targets) {
    const translatedStrings = await translateStrings(sourceStrings, language, target);
    if (!Array.isArray(translatedStrings) || translatedStrings.length !== sourceStrings.length ||
        translatedStrings.some((item) => typeof item !== 'string')) {
      throw new Error('Translation response did not include all topic content.');
    }
    let cursor = 0;
    const localized = {
      ...topic,
      question: translatedStrings[cursor++],
      lessons: [],
    };
    for (const lesson of topic.lessons ?? []) {
      const localizedLesson = {
        ...lesson,
        title: translatedStrings[cursor++],
        content: translatedStrings[cursor++],
        exercises: [],
      };
      for (const exercise of lesson.exercises ?? []) {
        const expectedStrings = exerciseText.get(exercise) ?? [];
        let exerciseCursor = 0;
        const payload = await translateExercisePayload(
          exercise.payload, language, target,
          async (strings) => {
            const values = translatedStrings.slice(cursor, cursor + strings.length);
            cursor += strings.length;
            exerciseCursor += strings.length;
            return values;
          },
        );
        if (exerciseCursor !== expectedStrings.length) {
          throw new Error('Could not preserve the translated exercise structure.');
        }
        localizedLesson.exercises.push({...exercise, payload});
      }
      localized.lessons.push(localizedLesson);
    }
    translations[target] = localized;
  }
  return translations;
}

export async function translateExercisePayload(payload, source, target, translateStrings) {
  const strings = [];
  const encode = (value, key = '') => {
    if (typeof value === 'string') {
      if (protectedFields.has(key) || key.endsWith('Id') || /^https?:\/\//i.test(value)) return value;
      if (!value.trim()) return value;
      const index = strings.push(value) - 1;
      return {[TRANSLATION_TOKEN]: index};
    }
    if (Array.isArray(value)) return value.map((item) => encode(item, key));
    if (!value || typeof value !== 'object') return value;
    if (key === 'consequences') {
      return {[CONSEQUENCE_TOKEN]: Object.entries(value).map(([label, consequence]) => [
        encode(label, 'consequenceLabel'), encode(consequence, 'consequence'),
      ])};
    }
    return Object.fromEntries(Object.entries(value).map(([childKey, child]) => [
      childKey, encode(child, childKey),
    ]));
  };
  const template = encode(payload);
  const translated = await translateStrings(strings, source, target);
  if (!Array.isArray(translated) || translated.length !== strings.length ||
      translated.some((item) => typeof item !== 'string')) {
    throw new Error('Translation response did not include all exercise text.');
  }
  const decode = (value) => {
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      if (Object.hasOwn(value, TRANSLATION_TOKEN)) return translated[value[TRANSLATION_TOKEN]];
      if (Object.hasOwn(value, CONSEQUENCE_TOKEN)) {
        return Object.fromEntries(value[CONSEQUENCE_TOKEN].map(([label, consequence]) => [decode(label), decode(consequence)]));
      }
      return Object.fromEntries(Object.entries(value).map(([key, child]) => [key, decode(child)]));
    }
    if (Array.isArray(value)) return value.map(decode);
    return value;
  };
  return decode(template);
}

function validateSourceLanguage(language) {
  if (!LANGUAGE_CODES.has(language)) throw new Error('Choose a supported translation language.');
}
