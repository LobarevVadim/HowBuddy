import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';

export const LESSON_LANGUAGES = Object.freeze({
  en: 'lesson_exercises.json',
  fr: 'lesson_exercises_fr.json',
  hi: 'lesson_exercises_hi.json',
  es: 'lesson_exercises_es.json',
  ru: 'lesson_exercises_ru.json',
});

const DEFAULT_DATA_DIRECTORY = new URL('../data/', import.meta.url);

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

export function readLessonContentSeeds(directory = DEFAULT_DATA_DIRECTORY) {
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

export async function importLessonContent(pool, seeds = readLessonContentSeeds()) {
  for (const seed of seeds) {
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

export async function loadLessonContent(pool) {
  const result = await pool.query(
    `SELECT language_code, content
     FROM lesson_content_by_language
     WHERE language_code = ANY($1::text[])`,
    [Object.keys(LESSON_LANGUAGES)],
  );
  const contentByLanguage = new Map();
  for (const row of result.rows) {
    const content = typeof row.content === 'string' ? JSON.parse(row.content) : row.content;
    contentByLanguage.set(row.language_code, validateLessonContent(content, row.language_code));
  }
  if (!contentByLanguage.has('en')) {
    throw new Error('English lesson content is missing from the content database.');
  }
  return contentByLanguage;
}

export function getLessonContent(contentByLanguage, language) {
  const code = Object.hasOwn(LESSON_LANGUAGES, String(language)) ? String(language) : 'en';
  return contentByLanguage.get(code) ?? contentByLanguage.get('en');
}

