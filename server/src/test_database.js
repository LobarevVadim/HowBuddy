import pg from 'pg';
import {randomUUID} from 'node:crypto';
import {readFile} from 'node:fs/promises';

// Deliberately never fall back to DATABASE_URL or dotenv. Tests require a
// loopback server, dedicated role/database, and their own random schema.
export async function createTestDatabase(t) {
  const url = new URL(process.env.HOWBUDDY_TEST_DATABASE_URL);
  if (!['127.0.0.1', 'localhost', '[::1]'].includes(url.hostname) ||
      url.username !== 'howbuddy_test' || url.pathname !== '/howbuddy_test') {
    throw new Error('Tests require a loopback howbuddy_test database and role.');
  }
  const schema = `test_${randomUUID().replaceAll('-', '')}`;
  const admin = new pg.Pool({connectionString: url.href});
  await admin.query(`CREATE SCHEMA ${schema}`);
  const pool = new pg.Pool({connectionString: url.href, options: `-c search_path=${schema},public`});
  t.after(async () => {
    await pool.end();
    await admin.query(`DROP SCHEMA ${schema} CASCADE`);
    await admin.end();
  });
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    // Node discovers test files in parallel processes. Serialize shared extension
    // bootstrap and keep the extension outside schemas owned by individual tests.
    await client.query("SELECT pg_advisory_xact_lock(hashtext('howbuddy-test-bootstrap'))");
    await client.query('CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public');
    await client.query(await readFile(new URL('../schema.sql', import.meta.url), 'utf8'));
    await client.query(await readFile(new URL('../migrations/001_completion_receipts.sql', import.meta.url), 'utf8'));
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally { client.release(); }
  return pool;
}
