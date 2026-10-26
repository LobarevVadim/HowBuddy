import test from 'node:test';
import assert from 'node:assert/strict';
import {
  LESSON_LANGUAGES,
  getLessonContent,
  importLessonContent,
  loadLessonContent,
  readLessonContentSeeds,
  validateLessonContent,
} from './lesson_content_store.js';

function memoryPool(initialRows = []) {
  const rows = new Map(initialRows.map((row) => [row.language_code, row]));
  return {
    rows,
    async query(sql, params = []) {
      if (sql.includes('SELECT language_code, content')) {
        return {rowCount: rows.size, rows: [...rows.values()]};
      }
      if (sql.includes('INSERT INTO lesson_content_by_language')) {
        const [language, encodedContent, sourceHash] = params;
        const existing = rows.get(language);
        if (!sql.includes('DO NOTHING') || !existing) {
          rows.set(language, {
            language_code: language,
            content: JSON.parse(encodedContent),
            source_sha256: sourceHash,
          });
        }
        return {rowCount: 1, rows: []};
      }
      throw new Error(`Unexpected SQL in content-store test: ${sql}`);
    },
  };
}

test('seed files provide validated content for all five languages', () => {
  const seeds = readLessonContentSeeds();
  assert.deepEqual(seeds.map((seed) => seed.language).sort(), Object.keys(LESSON_LANGUAGES).sort());
  for (const seed of seeds) {
    assert.ok(seed.content.roots.length > 0, `${seed.language} has root topics`);
    assert.equal(seed.sourceHash.length, 64);
  }
});

test('content loads from database rows by language without reading seed files', async () => {
  const pool = memoryPool();
  const seeds = readLessonContentSeeds();
  await importLessonContent(pool, seeds);

  const loaded = await loadLessonContent(pool);
  for (const language of Object.keys(LESSON_LANGUAGES)) {
    assert.deepEqual(getLessonContent(loaded, language), pool.rows.get(language).content);
  }
  assert.equal(getLessonContent(loaded, 'unsupported'), loaded.get('en'));
});

test('explicit content import updates existing language rows', async () => {
  const pool = memoryPool();
  const seeds = readLessonContentSeeds();
  assert.equal(await importLessonContent(pool, seeds), 5);
  const originalHash = pool.rows.get('en').source_sha256;
  const changed = {...seeds[0], sourceHash: 'a'.repeat(64)};
  await importLessonContent(pool, [changed]);
  assert.notEqual(pool.rows.get('en').source_sha256, originalHash);
});

test('invalid lesson content is rejected before import', () => {
  assert.throws(() => validateLessonContent({roots: ['missing'], nodes: {}}, 'en'));
});
