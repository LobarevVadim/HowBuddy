import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {loadNormalizedLessonContent, migrateLegacyLessonContent, normalizedContentExists} from './normalized_lesson_content.js';

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

export function readLessonContentSeeds(directory) {
  if (!directory) {
    throw new Error('Provide a directory containing the five lesson JSON files.');
  }
  return Object.entries(LESSON_LANGUAGES).map(([language, filename]) => {
    const fileUrl = new URL(filename, directory);
    const source = readFileSync(fileUrl, 'utf8');
    let content;
    try {
      content = JSON.parse(source);
    } catch (error) {
      throw new Error(`Could not parse ${filename}: ${error.message}`);
    }
    validateLessonContent(content, language);
    return {
      language,
      content,
      sourceHash: createHash('sha256').update(source).digest('hex'),
    };
  });
}

export async function ensureLessonContentSchema(pool) {
  const schema = readFileSync(new URL('../content_schema.sql', import.meta.url), 'utf8');
  await pool.query(schema);
}

export async function importLessonContent(pool, seeds) {
  if (!Array.isArray(seeds) || !seeds.length) {
    throw new Error('No validated lesson content records were provided.');
  }
  for (const seed of seeds) {
    validateLessonContent(seed.content, seed.language);
    await pool.query(
      `INSERT INTO lesson_content_by_language (language_code, content, source_sha256)
       VALUES ($1, $2::jsonb, $3)
       ON CONFLICT (language_code) DO UPDATE SET
         content = EXCLUDED.content,
         source_sha256 = EXCLUDED.source_sha256,
         updated_at = now()`,
      [seed.language, JSON.stringify(seed.content), seed.sourceHash],
    );
  }
  return seeds.length;
}

export async function loadLessonContent(pool, languages = ['en']) {
  const requestedLanguages = [...new Set(languages.map(String))]
    .filter((language) => Object.hasOwn(LESSON_LANGUAGES, language));
  if (!requestedLanguages.length) return new Map();
  if (await normalizedContentExists(pool)) {
    const contentByLanguage = new Map();
    const languagesToLoad = [...new Set([...requestedLanguages, 'en'])];
    for (const language of languagesToLoad) {
      contentByLanguage.set(language, await loadNormalizedLessonContent(pool, language));
    }
    return contentByLanguage;
  }
  const result = await pool.query(
    `SELECT language_code, content
     FROM lesson_content_by_language
     WHERE language_code = ANY($1::text[])`,
    [requestedLanguages],
  );
  const contentByLanguage = new Map();
  for (const row of result.rows) {
    const content = typeof row.content === 'string' ? JSON.parse(row.content) : row.content;
    contentByLanguage.set(row.language_code, validateLessonContent(content, row.language_code));
  }
  if (requestedLanguages.includes('en') && !contentByLanguage.has('en')) {
    throw new Error('English lesson content is missing from the content database.');
  }
  return contentByLanguage;
}

export {migrateLegacyLessonContent};

export function getLessonContent(contentByLanguage, language) {
  const code = Object.hasOwn(LESSON_LANGUAGES, String(language)) ? String(language) : 'en';
  return contentByLanguage.get(code) ?? contentByLanguage.get('en');
}

