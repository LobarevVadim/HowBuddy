import dotenv from 'dotenv';
import pg from 'pg';
import {resolve, sep} from 'node:path';
import {pathToFileURL} from 'node:url';
import {
  ensureLessonContentSchema,
  importLessonContent,
  readLessonContentSeeds,
} from './lesson_content_store.js';

dotenv.config();

const connectionString = process.env.DATABASE_URL;
if (!connectionString) {
  throw new Error('Set DATABASE_URL to the existing HowBuddy PostgreSQL database.');
}
const contentDirectory = process.env.LESSON_CONTENT_DIR;
if (!contentDirectory) {
  throw new Error('Set LESSON_CONTENT_DIR to a directory containing all five lesson JSON files.');
}

const pool = new pg.Pool({connectionString});
try {
  await ensureLessonContentSchema(pool);
  const sourceDirectory = pathToFileURL(`${resolve(contentDirectory)}${sep}`);
  const importedLanguages = await importLessonContent(pool, readLessonContentSeeds(sourceDirectory));
  console.log(`Imported or updated ${importedLanguages} lesson language records.`);
} finally {
  await pool.end();
}
