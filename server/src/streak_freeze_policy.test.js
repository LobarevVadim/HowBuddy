import test from 'node:test';
import assert from 'node:assert/strict';
import {
  claimStreakFreezeAlert,
  countStreakThroughToday,
  isStreakFreezeAlertDue,
  planMissedStreakFreezeDays,
  streakFreezeAlertCopy,
  streakFreezeAlertDate,
} from './streak_freeze_policy.js';
import {localClock} from './notification_policy.js';

test('one missed local calendar day consumes one available freeze', () => {
  assert.deepEqual(planMissedStreakFreezeDays({
    today: '2026-10-24', lastActivityDate: '2026-10-22', freezeBalance: 1,
  }), ['2026-10-23']);
});

test('does not process today before that local calendar day is complete', () => {
  assert.deepEqual(planMissedStreakFreezeDays({
    today: '2026-10-23', lastActivityDate: '2026-10-22', freezeBalance: 3,
  }), []);
});

test('catches up consecutive missed days after a service restart, bounded by balance', () => {
  assert.deepEqual(planMissedStreakFreezeDays({
    today: '2026-10-27', lastActivityDate: '2026-10-22', freezeBalance: 2,
  }), ['2026-10-23', '2026-10-24']);
});

test('the latest study or freeze date prevents duplicate spending on retries', () => {
  assert.deepEqual(planMissedStreakFreezeDays({
    today: '2026-10-24', lastActivityDate: '2026-10-23', freezeBalance: 4,
  }), []);
});

test('does not spend freezes when no lesson or frozen day exists', () => {
  assert.deepEqual(planMissedStreakFreezeDays({
    today: '2026-10-24', lastActivityDate: null, freezeBalance: 4,
  }), []);
});

test('no available freezes leaves the missed day for normal streak expiration', () => {
  assert.deepEqual(planMissedStreakFreezeDays({
    today: '2026-10-24', lastActivityDate: '2026-10-22', freezeBalance: 0,
  }), []);
});

test('a frozen calendar date keeps the consecutive streak alive', () => {
  assert.equal(countStreakThroughToday({
    today: '2026-10-24',
    studyDays: ['2026-10-22', '2026-10-24'],
    frozenDays: ['2026-10-23'],
  }), 3);
});

test('without a freeze, a missed date expires the previous streak', () => {
  assert.equal(countStreakThroughToday({
    today: '2026-10-24',
    studyDays: ['2026-10-22', '2026-10-24'],
  }), 1);
});

test('local calendar date follows the configured zone across daylight-saving changes', () => {
  assert.equal(
    localClock(new Date('2026-03-08T04:59:00.000Z'), 'America/Toronto').date,
    '2026-03-07',
  );
  assert.equal(
    localClock(new Date('2026-03-08T05:00:00.000Z'), 'America/Toronto').date,
    '2026-03-08',
  );
  assert.equal(
    localClock(new Date('2026-11-01T05:59:00.000Z'), 'America/Toronto').date,
    '2026-11-01',
  );
  assert.equal(
    localClock(new Date('2026-11-01T06:00:00.000Z'), 'America/Toronto').date,
    '2026-11-01',
  );
});

test('a freeze created before 9 a.m. alerts that morning in the account timezone', () => {
  assert.equal(
    streakFreezeAlertDate(new Date('2026-10-24T12:00:00.000Z'), 'America/Toronto'),
    '2026-10-24',
  );
  assert.equal(isStreakFreezeAlertDue({
    now: new Date('2026-10-24T13:00:00.000Z'),
    timeZone: 'America/Toronto',
    notifyOn: '2026-10-24',
  }), true);
});

test('a freeze created after 9 a.m. alerts the next local morning', () => {
  assert.equal(
    streakFreezeAlertDate(new Date('2026-10-24T15:00:00.000Z'), 'America/Toronto'),
    '2026-10-25',
  );
  assert.equal(isStreakFreezeAlertDue({
    now: new Date('2026-10-25T13:00:00.000Z'),
    timeZone: 'America/Toronto',
    notifyOn: '2026-10-25',
  }), true);
});

test('freeze saved alert has the requested copy and remaining balance', () => {
  const copy = streakFreezeAlertCopy(2);
  assert.equal(copy.title, '❄️ Your streak was saved!');
  assert.equal(copy.body, 'Bobo used 1 streak freeze to protect your progress. 🔥 Complete a lesson today to keep going! You have 2 freezes left.');
});

test('freeze saved alert copy is available in each supported language', () => {
  for (const language of ['en', 'fr', 'ru', 'es', 'hi']) {
    const copy = streakFreezeAlertCopy(3, language);
    assert.ok(copy.title.startsWith('❄️'));
    assert.ok(copy.body.includes('3'));
  }
});

test('a frozen-day alert claim can only succeed once', async () => {
  let isClaimed = false;
  const pool = {
    async query() {
      if (isClaimed) return {rowCount: 0};
      isClaimed = true;
      return {rowCount: 1};
    },
  };
  assert.equal(await claimStreakFreezeAlert(pool, 'account-1', '2026-10-23'), true);
  assert.equal(await claimStreakFreezeAlert(pool, 'account-1', '2026-10-23'), false);
});
