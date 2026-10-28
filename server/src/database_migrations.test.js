import test from 'node:test';
import assert from 'node:assert/strict';
import {createTestDatabase} from './test_database.js';
import {migrateDatabase} from './database_migrations.js';

test('additive migrations replay safely and content publication generation rolls back with its transaction',
  {skip: !process.env.HOWBUDDY_TEST_DATABASE_URL}, async (t) => {
    const pool = await createTestDatabase(t);
    await migrateDatabase(pool);
    await migrateDatabase(pool);
    assert.equal((await pool.query('SELECT count(*)::int AS count FROM schema_migrations')).rows[0].count, 2);
    const initial = (await pool.query('SELECT generation FROM content_generation')).rows[0].generation;
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query("INSERT INTO content_topics(topic_id,tree_position,level) VALUES('cells',0,1)");
      await client.query('ROLLBACK');
    } finally { client.release(); }
    assert.equal((await pool.query('SELECT generation FROM content_generation')).rows[0].generation, initial);
    await pool.query("INSERT INTO content_topics(topic_id,tree_position,level) VALUES('cells',0,1)");
    assert.notEqual((await pool.query('SELECT generation FROM content_generation')).rows[0].generation, initial);
  });
