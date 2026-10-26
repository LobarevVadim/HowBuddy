import dotenv from 'dotenv';
import pg from 'pg';
import {ensureLessonContentSchema, importLessonContent} from './lesson_content_store.js';

dotenv.config();

const connectionString = process.env.DATABASE_URL;
if (!connectionString) {
  throw new Error('Set DATABASE_URL to the existing HowBuddy PostgreSQL database.');
}

const pool = new pg.Pool({connectionString});
try {
  await ensureLessonContentSchema(pool);
  const importedLanguages = await importLessonContent(pool);
  console.log(`Imported or updated ${importedLanguages} lesson language records.`);
} finally {
  await pool.end();
}
