import {readFile} from 'node:fs/promises';

export async function migrateDatabase(pool) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query("SELECT pg_advisory_xact_lock(hashtext('howbuddy-schema-migrations'))");
    if (!(await client.query("SELECT to_regclass('accounts') AS name")).rows[0].name) {
      await client.query(await readFile(new URL('../schema.sql', import.meta.url), 'utf8'));
    }
    if (!(await client.query("SELECT to_regclass('content_topics') AS name")).rows[0].name) {
      const legacySchema = await readFile(new URL('../content_schema.sql', import.meta.url), 'utf8');
      const cleanup = legacySchema.indexOf('-- The normalized migration');
      if (cleanup < 0) throw new Error('Content bootstrap boundary is missing.');
      // Existing schema file also contains historical public-schema DROP jobs.
      // Bootstrap only its CREATE statements; never replay historical cleanup.
      await client.query(legacySchema.slice(0, cleanup));
    }
    await client.query('CREATE TABLE IF NOT EXISTS schema_migrations(version TEXT PRIMARY KEY, applied_at TIMESTAMPTZ NOT NULL DEFAULT now())');
    for (const version of ['001_completion_receipts.sql', '002_content_generation.sql']) {
      if ((await client.query('SELECT 1 FROM schema_migrations WHERE version=$1', [version])).rowCount) continue;
      await client.query(await readFile(new URL(`../migrations/${version}`, import.meta.url), 'utf8'));
      await client.query('INSERT INTO schema_migrations(version) VALUES($1)', [version]);
    }
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally { client.release(); }
}
