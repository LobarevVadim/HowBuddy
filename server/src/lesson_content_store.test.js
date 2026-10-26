import test from 'node:test';
import assert from 'node:assert/strict';
import {
  LESSON_LANGUAGES,
  getLessonContent,
  importLessonContent,
  loadLessonContent,
  validateLessonContent,
} from './lesson_content_store.js';

const seeds = Object.keys(LESSON_LANGUAGES).map((language, index) => {
  const id = `${language}-root`;
  return {
    language,
    content: {
      roots: [id],
      nodes: {[id]: {id, question: `Question ${language}`, children: []}},
    },
    sourceHash: String(index).repeat(64),
  };
});

function memoryPool(initialRows = []) {
  const rows = new Map(initialRows.map((row) => [row.language_code, row]));
  const requestedLanguages = [];
  return {
    rows,
    requestedLanguages,
    async query(sql, params = []) {
      if (sql.includes('SELECT language_code, content')) {
        requestedLanguages.push(params[0]);
        const selected = [...rows.values()].filter((row) => params[0].includes(row.language_code));
        return {rowCount: selected.length, rows: selected};
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

test('loads English by default and can load another requested language on demand', async () => {
  const rows = seeds.map(({language, content, sourceHash}) => ({
    language_code: language,
    content,
    source_sha256: sourceHash,
  }));
  const pool = memoryPool(rows);
  const english = await loadLessonContent(pool, ['en']);
  assert.deepEqual(pool.requestedLanguages, [['en']]);
  assert.deepEqual(getLessonContent(english, 'en'), rows[0].content);
  assert.equal(getLessonContent(english, 'unsupported'), rows[0].content);

  const french = await loadLessonContent(pool, ['fr']);
  assert.deepEqual(pool.requestedLanguages, [['en'], ['fr']]);
  assert.deepEqual(getLessonContent(french, 'fr'), rows[1].content);
});

test('explicit content import updates the requested language rows', async () => {
  const pool = memoryPool();
  assert.equal(await importLessonContent(pool, seeds), 5);
  const originalHash = pool.rows.get('en').source_sha256;
  const changed = {...seeds[0], sourceHash: 'a'.repeat(64)};
  await importLessonContent(pool, [changed]);
  assert.notEqual(pool.rows.get('en').source_sha256, originalHash);
});

test('invalid lesson content is rejected', () => {
  assert.throws(() => validateLessonContent({roots: ['missing'], nodes: {}}, 'en'));
});
