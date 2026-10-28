import test from 'node:test';
import assert from 'node:assert/strict';
import {createRevisionCache} from './revision_cache.js';

test('in-flight old content cannot repopulate the cache after publication', async () => {
  let revision = 1;
  let finishOld;
  let loads = 0;
  const cache = createRevisionCache({revision: async () => revision, load: async () => {
    loads++;
    if (loads === 1) return new Promise((resolve) => { finishOld = resolve; });
    return 'new';
  }});
  const pending = cache.get('en');
  while (!finishOld) await new Promise(setImmediate);
  revision++;
  assert.equal(await cache.get('en'), 'new');
  finishOld('old');
  assert.equal(await pending, 'new');
  assert.equal(await cache.get('en'), 'new');
});

test('another instance sees changed revision and duplicate reads share a load', async () => {
  let revision = 1;
  let loads = 0;
  const make = () => createRevisionCache({revision: async () => revision, load: async () => { loads++; return revision; }});
  const first = make();
  const second = make();
  assert.deepEqual(await Promise.all([first.get('en'), first.get('en')]), [1, 1]);
  assert.equal(loads, 1);
  await second.get('en');
  revision = 2;
  assert.equal(await first.get('en'), 2);
  assert.equal(await second.get('en'), 2);
});
