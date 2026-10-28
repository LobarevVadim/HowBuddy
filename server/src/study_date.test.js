import test from 'node:test';
import assert from 'node:assert/strict';
import {studyDate} from './study_date.js';

test('study day uses server time in the client zone, including DST, without trusting a supplied date', () => {
  assert.equal(studyDate({timeZone: 'America/Toronto', now: new Date('2026-03-08T04:30:00Z')}), '2026-03-07');
  assert.equal(studyDate({timeZone: 'America/Toronto', now: new Date('2026-03-08T07:30:00Z')}), '2026-03-08');
  assert.equal(studyDate({timeZone: 'invalid', offsetMinutes: 120, now: new Date('2026-10-27T23:30:00Z')}), '2026-10-28');
  assert.equal(studyDate({offsetMinutes: 99999, now: new Date('2026-10-27T23:30:00Z')}), '2026-10-27');
});
