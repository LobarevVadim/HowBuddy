import dotenv from 'dotenv';
import pg from 'pg';
import {migrateDatabase} from './database_migrations.js';

dotenv.config();
if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required for an explicitly requested migration.');
const pool = new pg.Pool({connectionString: process.env.DATABASE_URL});
try {
  await migrateDatabase(pool);
  console.log('Database migrations applied.');
} finally { await pool.end(); }
