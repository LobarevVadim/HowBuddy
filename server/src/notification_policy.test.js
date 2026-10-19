import test from 'node:test';
import assert from 'node:assert/strict';
import {
  DAILY_LIMIT,
  INACTIVITY_MESSAGES,
  chooseNotification,
  countStreakEndingYesterday,
  deliveryIdempotencyKey,
  isInQuietHours,
  localClock,
  localDateDifference,
} from './notification_policy.js';

const today = '2026-10-19';
const dateAt = (offset) => {
  const date = new Date(`${today}T00:00:00.000Z`);
  date.setUTCDate(date.getUTCDate() - offset);
  return date.toISOString().slice(0, 10);
};

test('completed today suppresses the morning lesson reminder', () => {
  assert.equal(chooseNotification({slot:'morning',today,lastStudyDate:today,studiedToday:true}), null);
});

test('active streak with no lesson today receives a streak warning', () => {
  const yesterday = dateAt(1);
  const result = chooseNotification({slot:'evening',today,lastStudyDate:yesterday,studyDates:[yesterday]});
  assert.equal(result.type, 'streak_warning');
  assert.match(result.title, /1-day streak/);
});

test('inactive days 2 through 8 receive their matching messages', () => {
  for (let days = 2; days <= 8; days++) {
    const result = chooseNotification({slot:'evening',today,lastStudyDate:dateAt(days)});
    assert.equal(result.type, 'inactivity');
    assert.ok(result.title.startsWith(INACTIVITY_MESSAGES[days].slice(0, 2)));
  }
});

test('every inactivity threshold from 2 through 41 has a message', () => {
  for (let days = 2; days <= 41; days++) {
    assert.ok(INACTIVITY_MESSAGES[days], `missing day ${days}`);
    assert.equal(chooseNotification({slot:'evening',today,lastStudyDate:dateAt(days)}).type, 'inactivity');
  }
});

test('a returning learner after 20 days receives today’s single inactivity reminder, not a catch-up burst', () => {
  const result = chooseNotification({slot:'evening',today,lastStudyDate:dateAt(20)});
  assert.equal(result.type, 'inactivity');
  assert.equal(result.localDate, today);
});

test('disabled notifications suppress all types', () => {
  for (const slot of ['morning','afternoon','evening']) {
    assert.equal(chooseNotification({slot,today,enabled:false,question:'Why?',lastStudyDate:dateAt(2)}), null);
  }
});

test('quiet hours suppress notifications across midnight', () => {
  assert.equal(isInQuietHours(23 * 60, 22 * 60, 8 * 60), true);
  assert.equal(isInQuietHours(7 * 60 + 59, 22 * 60, 8 * 60), true);
  assert.equal(isInQuietHours(8 * 60, 22 * 60, 8 * 60), false);
  assert.equal(chooseNotification({slot:'morning',today,localMinutes:7*60+59}), null);
});

test('daily cap prevents more than three sends', () => {
  assert.equal(DAILY_LIMIT, 3);
  assert.equal(chooseNotification({slot:'afternoon',today,question:'Why?',dailyCount:3}), null);
});

test('local dates follow the selected timezone after a timezone change', () => {
  const instant = new Date('2026-10-19T01:00:00Z');
  assert.equal(localClock(instant,'America/Toronto').date, '2026-10-18');
  assert.equal(localClock(instant,'Asia/Kolkata').date, '2026-10-19');
});

test('spring daylight saving transition skips the missing local hour', () => {
  const before = localClock(new Date('2026-03-08T06:59:00Z'),'America/New_York');
  const after = localClock(new Date('2026-03-08T07:00:00Z'),'America/New_York');
  assert.equal(before.hour, 1);
  assert.equal(after.hour, 3);
  assert.equal(before.date, after.date);
});

test('fall daylight saving transition repeats an hour without repeating a daily delivery key', () => {
  const first = localClock(new Date('2026-11-01T05:30:00Z'),'America/New_York');
  const second = localClock(new Date('2026-11-01T06:30:00Z'),'America/New_York');
  assert.equal(first.hour, 1);
  assert.equal(second.hour, 1);
  assert.equal(deliveryIdempotencyKey('u1',first.date,'daily_lesson'), deliveryIdempotencyKey('u1',second.date,'daily_lesson'));
});

test('delivery key is unique by account, local date, and type', () => {
  assert.equal(deliveryIdempotencyKey('a','2026-10-19','daily_lesson'), 'a:2026-10-19:daily_lesson');
});

test('curiosity payload carries a topic target for notification navigation', () => {
  const result = chooseNotification({slot:'afternoon',today,question:'Why do we dream?',topicId:'dreams'});
  assert.equal(result.topicId, 'dreams');
  assert.match(result.title, /Why do we dream/);
});

test('a user with no previous lessons still gets the daily reminder, not inactivity copy', () => {
  const result = chooseNotification({slot:'morning',today,lastStudyDate:null,studiedToday:false});
  assert.equal(result.type, 'daily_lesson');
});

test('notification messages are available in every supported language', () => {
  for (const language of ['en', 'fr', 'es', 'ru', 'hi']) {
    const cases = [
      {slot: 'morning', lastStudyDate: null},
      {slot: 'morning', lastStudyDate: dateAt(2)},
      {slot: 'afternoon', question: 'Why does the body work?'},
      {slot: 'evening', studiedToday: true, lastStudyDate: today, question: 'Why do we sleep?'},
      {slot: 'evening', lastStudyDate: dateAt(5)},
    ];
    for (const scenario of cases) {
      const message = chooseNotification({today, language, ...scenario});
      assert.ok(message?.title, `${language} ${scenario.slot} title`);
      assert.doesNotMatch(`${message.title}${message.body}`, /\uFFFD/);
    }
  }
});

test('every inactivity reminder from day 2 through 41 is localized in all five languages', () => {
  for (const language of ['en', 'fr', 'es', 'ru', 'hi']) {
    for (let days = 2; days <= 41; days++) {
      const message = chooseNotification({
        slot: 'evening',
        today,
        language,
        lastStudyDate: dateAt(days),
      });
      assert.equal(message?.type, 'inactivity', `${language}, day ${days}`);
      assert.ok(message.title, `${language}, day ${days} has a title`);
      assert.doesNotMatch(message.title, /\uFFFD/);
      if (language !== 'en') {
        assert.notEqual(message.title, INACTIVITY_MESSAGES[days], `${language}, day ${days}`);
      }
    }
  }
});

test('expired streak is not described as an active streak', () => {
  const result = chooseNotification({slot:'evening',today,lastStudyDate:dateAt(2),studyDates:[dateAt(2)]});
  assert.equal(result.type, 'inactivity');
  assert.doesNotMatch(result.title, /streak/i);
});

test('previously sent type prevents duplicate scheduling for the same local day', () => {
  const result = chooseNotification({slot:'morning',today,lastStudyDate:null,alreadySent:new Set(['daily_lesson'])});
  assert.equal(result, null);
});

test('contiguous streak counts consecutive local calendar dates', () => {
  assert.equal(countStreakEndingYesterday(today,[dateAt(1),dateAt(2),dateAt(4)]),2);
  assert.equal(localDateDifference(today,dateAt(2)),2);
});
