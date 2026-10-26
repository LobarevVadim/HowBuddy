import pg from 'pg';
import {ensureLessonContentSchema, importLessonContent} from './lesson_content_store.js';

const connectionString = process.env.CONTENT_DATABASE_URL || process.env.DATABASE_URL;
if (!connectionString) {
  throw new Error('Set CONTENT_DATABASE_URL (or DATABASE_URL) to the target PostgreSQL database.');
}

const pool = new pg.Pool({connectionString});
try {
  await ensureLessonContentSchema(pool);
  const importedLanguages = await importLessonContent(pool);
  console.log(`Imported or updated ${importedLanguages} lesson language records.`);
} finally {
  await pool.end();
}
