import {localClock} from './notification_policy.js';

export function previousCalendarDay(date) {
  const value = new Date(`${date}T00:00:00.000Z`);
  value.setUTCDate(value.getUTCDate() - 1);
  return value.toISOString().slice(0, 10);
}

export function nextCalendarDay(date) {
  const value = new Date(`${date}T00:00:00.000Z`);
  value.setUTCDate(value.getUTCDate() + 1);
  return value.toISOString().slice(0, 10);
}

export function planMissedStreakFreezeDays({today, lastActivityDate, freezeBalance}) {
  if (!lastActivityDate || freezeBalance < 1 || lastActivityDate >= today) return [];

  const dueThrough = previousCalendarDay(today);
  const dates = [];
  let date = nextCalendarDay(lastActivityDate);
  while (date <= dueThrough && dates.length < freezeBalance) {
    dates.push(date);
    date = nextCalendarDay(date);
  }
  return dates;
}

export function countStreakThroughToday({today, studyDays, frozenDays = []}) {
  const activeDays = new Set([...studyDays, ...frozenDays]);
  let cursor = new Date(`${today}T00:00:00.000Z`);
  if (!activeDays.has(today)) cursor.setUTCDate(cursor.getUTCDate() - 1);

  let streak = 0;
  while (activeDays.has(cursor.toISOString().slice(0, 10))) {
    streak++;
    cursor.setUTCDate(cursor.getUTCDate() - 1);
  }
  return streak;
}

export function streakFreezeAlertDate(now, timeZone) {
  const clock = localClock(now, timeZone);
  return clock.hour < 9 ? clock.date : nextCalendarDay(clock.date);
}

export function isStreakFreezeAlertDue({now, timeZone, notifyOn}) {
  const clock = localClock(now, timeZone);
  return clock.date >= notifyOn && (clock.date > notifyOn || clock.hour >= 9);
}

export function streakFreezeAlertCopy(freezesRemaining, language = 'en') {
  const copy = {
    en: [
      '❄️ Your streak was saved!',
      `Bobo used 1 streak freeze to protect your progress. 🔥 Complete a lesson today to keep going! You have ${freezesRemaining} freezes left.`,
    ],
    fr: [
      '❄️ Ta série est sauvée !',
      `Bobo a utilisé 1 gel de série pour protéger tes progrès. 🔥 Termine une leçon aujourd’hui pour continuer ! Il te reste ${freezesRemaining} gels.`,
    ],
    ru: [
      '❄️ Твоя серия спасена!',
      `Бобо использовал одну защиту серии, чтобы сохранить твой прогресс. 🔥 Пройди урок сегодня, чтобы продолжить! Осталось защит: ${freezesRemaining}.`,
    ],
    es: [
      '❄️ ¡Tu racha está a salvo!',
      `Bobo usó una protección de racha para guardar tu progreso. 🔥 ¡Completa una lección hoy para continuar! Te quedan ${freezesRemaining} protecciones.`,
    ],
    hi: [
      '❄️ आपकी स्ट्रीक बच गई!',
      `बोबो ने आपकी प्रगति बचाने के लिए 1 स्ट्रीक फ़्रीज़ इस्तेमाल किया। 🔥 आगे बढ़ने के लिए आज एक पाठ पूरा करें! आपके पास ${freezesRemaining} फ़्रीज़ बचे हैं।`,
    ],
  }[language] ?? [
    '❄️ Your streak was saved!',
    `Bobo used 1 streak freeze to protect your progress. 🔥 Complete a lesson today to keep going! You have ${freezesRemaining} freezes left.`,
  ];
  return {title: copy[0], body: copy[1]};
}

export async function claimStreakFreezeAlert(pool, accountId, frozenDate) {
  const result = await pool.query(
    `UPDATE streak_freeze_alerts SET claimed_at = now()
     WHERE account_id = $1 AND frozen_date = $2::date AND claimed_at IS NULL
     RETURNING frozen_date`,
    [accountId, frozenDate],
  );
  return result.rowCount === 1;
}
