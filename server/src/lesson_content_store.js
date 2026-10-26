import {readFileSync} from 'node:fs';
import {loadNormalizedLessonContent, normalizedContentExists} from './normalized_lesson_content.js';

export const LESSON_LANGUAGES = Object.freeze({
  en: 'lesson_exercises.json',
  fr: 'lesson_exercises_fr.json',
  hi: 'lesson_exercises_hi.json',
  es: 'lesson_exercises_es.json',
  ru: 'lesson_exercises_ru.json',
});

export function validateLessonContent(value, language) {
  if (!value || typeof value !== 'object' || Array.isArray(value) ||
      !Array.isArray(value.roots) || value.roots.length === 0 ||
      !value.nodes || typeof value.nodes !== 'object' || Array.isArray(value.nodes)) {
    throw new Error(`Lesson content for ${language} must contain roots and nodes.`);
  }
  for (const root of value.roots) {
    if (typeof root !== 'string' || !value.nodes[root]) {
      throw new Error(`Lesson content for ${language} has an invalid root: ${root}.`);
    }
  }
  return value;
}

export async function ensureLessonContentSchema(pool) {
  const schema = readFileSync(new URL('../content_schema.sql', import.meta.url), 'utf8');
  await pool.query(schema);
}

export async function loadLessonContent(pool, languages = ['en']) {
  const requestedLanguages = [...new Set(languages.map(String))]
    .filter((language) => Object.hasOwn(LESSON_LANGUAGES, language));
  if (!requestedLanguages.length) return new Map();
  if (!await normalizedContentExists(pool)) {
    throw new Error('Normalized lesson content is empty.');
  }
  const contentByLanguage = new Map();
  const languagesToLoad = [...new Set([...requestedLanguages, 'en'])];
  for (const language of languagesToLoad) {
    const content = await loadNormalizedLessonContent(pool, language);
    contentByLanguage.set(language, validateLessonContent(content, language));
  }
  return contentByLanguage;
}

export function getLessonContent(contentByLanguage, language) {
  const code = Object.hasOwn(LESSON_LANGUAGES, String(language)) ? String(language) : 'en';
  return contentByLanguage.get(code) ?? contentByLanguage.get('en');
}

