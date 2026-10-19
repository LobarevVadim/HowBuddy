export const DAILY_LIMIT = 3;
export const INACTIVITY_MESSAGES = {
  2: '🥺 Bobo hasn\'t seen you in 2 days! Ready for a tiny biology adventure?',
  3: '🧠 Your brain loves learning! It\'s been 3 days since your last lesson.',
  4: '👀 Bobo is starting to wonder where you went. It\'s been 4 days!',
  5: '🔬 Five days without biology? Your next discovery is waiting!',
  6: '🫀 Your heart hasn\'t stopped working. Why should your curiosity?',
  7: '🌱 One week away! Bobo saved your spot in the learning tree.',
  8: '🧬 Eight days have passed, but your biology adventure is still here.',
  9: '🤔 Nine days away! Want to discover something surprising today?',
  10: '🎯 Ten days without a lesson. Just 3 minutes can restart your journey!',
  11: '🦴 Your bones are always rebuilding. Time to rebuild your learning habit?',
  12: '🧠 Twelve days away! Your next brain-boosting lesson is ready.',
  13: '🔍 Thirteen days without a discovery. Bobo has a mystery for you!',
  14: '🌎 Two weeks away! Your body is still full of unanswered questions.',
  15: '💡 Fifteen days later, and there\'s still so much to discover!',
  16: '🫁 You\'ve taken thousands of breaths since your last lesson. Know how they work?',
  17: '🧪 Seventeen days away! Your next experiment in curiosity awaits.',
  18: '🧠 Your brain can learn at any age. How about a quick lesson today?',
  19: '👋 Bobo says hello! It\'s been 19 days since your last discovery.',
  20: '🔬 Twenty days away! Your next biology mystery takes just 3 minutes.',
  21: '🌟 Three weeks away! Bobo would love to explore the human body with you again.',
  22: '🫀 Your heart has been busy for 22 days. Curious about what keeps it beating?',
  23: '🧬 Twenty-three days without a lesson. Your DNA is still full of mysteries!',
  24: '🦠 Your immune system never takes a day off. Want to learn its secrets?',
  25: '🎉 Twenty-five days away! A fresh start is always possible.',
  26: '🌱 Bobo\'s learning tree has more discoveries waiting for you!',
  27: '🧠 Twenty-seven days away! One little lesson could spark a big question.',
  28: '📚 Four weeks away! Your biology journey is ready whenever you are.',
  29: '🔍 Twenty-nine days later, and your next mystery is still waiting!',
  30: '🌙 A month away! Ever wondered why humans need to dream?',
  31: '🫀 Your body has kept you alive all month. Want to know how?',
  32: '🦴 Thirty-two days away! Your bones are stronger than you might think.',
  33: '🧬 Thirty-three days without biology. Bobo has something fascinating to show you!',
  34: '💡 Thirty-four days away! There\'s always another amazing thing to learn.',
  35: '🔬 Thirty-five days later, and the human body is still full of surprises.',
  36: '🧠 Your brain is always changing. Want to discover how?',
  37: '🌟 Thirty-seven days away! A new discovery is only one tap away.',
  38: '🫁 You\'ve been breathing all this time. Let\'s uncover how it works!',
  39: '👀 Thirty-nine days without HowBuddy. Your next mystery is ready!',
  40: '🧬 Forty days away! The human body has billions of stories to tell.',
  41: '💙 Bobo is still here after 41 days. Come back whenever you\'re curious!',
};

const COPY = {
  en: {
    daily: ['🧠 Bobo is waiting!', 'Ready for 3 minutes of biology?'],
    missed: ['👀 You missed yesterday!', 'Bobo has a new mystery waiting for you.'],
    streak: (streak) => [`🔥 Your ${streak}-day streak is at risk!`, 'One quick lesson will save it.'],
    afternoon: (question) => [`☀️ ${question}`, 'Come discover now!'],
    evening: (question) => [`🌙 ${question}`, 'Bobo has a 3-minute mystery for you!'],
    inactive: (days) => [INACTIVITY_MESSAGES[days]],
  },
  fr: {
    daily: ['🧠 Bobo t’attend !', 'Prêt pour 3 minutes de biologie ?'],
    missed: ['👀 Tu as manqué hier !', 'Bobo a une nouvelle énigme pour toi.'],
    streak: (streak) => [`🔥 Ta série de ${streak} jours est en danger !`, 'Une petite leçon peut la sauver.'],
    afternoon: (question) => [`☀️ ${question}`, 'Viens découvrir !'],
    evening: (question) => [`🌙 ${question}`, 'Bobo a une énigme de 3 minutes pour toi !'],
    inactive: (days) => [`💙 Bobo ne t’a pas vu depuis ${days} jours. Une petite aventure de biologie t’attend !`],
  },
  es: {
    daily: ['🧠 ¡Bobo te espera!', '¿Listo para 3 minutos de biología?'],
    missed: ['👀 ¡Ayer no viniste!', 'Bobo tiene un nuevo misterio para ti.'],
    streak: (streak) => [`🔥 ¡Tu racha de ${streak} días está en riesgo!`, 'Una lección rápida puede salvarla.'],
    afternoon: (question) => [`☀️ ${question}`, '¡Ven a descubrirlo!'],
    evening: (question) => [`🌙 ${question}`, '¡Bobo tiene un misterio de 3 minutos para ti!'],
    inactive: (days) => [`💙 ¡Hace ${days} días que Bobo no te ve! ¿Listo para una pequeña aventura de biología?`],
  },
  ru: {
    daily: ['🧠 Бобо ждёт!', 'Готовы к трём минутам биологии?'],
    missed: ['👀 Вас не было вчера!', 'У Бобо для вас новая загадка.'],
    streak: (streak) => [`🔥 Ваша серия из ${streak} дней под угрозой!`, 'Один короткий урок её спасёт.'],
    afternoon: (question) => [`☀️ ${question}`, 'Откройте для себя новое!'],
    evening: (question) => [`🌙 ${question}`, 'У Бобо есть загадка на три минуты!'],
    inactive: (days) => [`💙 Бобо не видел вас ${days} дн. Готовы к маленькому приключению в мире биологии?`],
  },
  hi: {
    daily: ['🧠 बोबो आपका इंतज़ार कर रहा है!', 'जीव-विज्ञान के 3 मिनट के लिए तैयार हैं?'],
    missed: ['👀 आप कल नहीं आए!', 'बोबो के पास आपके लिए एक नया रहस्य है।'],
    streak: (streak) => [`🔥 आपकी ${streak} दिनों की स्ट्रीक खतरे में है!`, 'एक छोटा पाठ इसे बचा सकता है।'],
    afternoon: (question) => [`☀️ ${question}`, 'आइए, जानें!'],
    evening: (question) => [`🌙 ${question}`, 'बोबो के पास 3 मिनट का रहस्य है!'],
    inactive: (days) => [`💙 बोबो ने आपको ${days} दिनों से नहीं देखा! जीव-विज्ञान का छोटा रोमांच शुरू करें?`],
  },
};

export function isValidTimeZone(timeZone) {
  try {
    new Intl.DateTimeFormat('en', {timeZone}).format(new Date());
    return true;
  } catch {
    return false;
  }
}

export function localClock(now, timeZone) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
  }).formatToParts(now);
  const values = Object.fromEntries(parts.map(({type, value}) => [type, value]));
  return {
    date: `${values.year}-${values.month}-${values.day}`,
    hour: Number(values.hour),
    minute: Number(values.minute),
  };
}

export function localDateDifference(today, previousDay) {
  const [year, month, day] = today.split('-').map(Number);
  const [previousYear, previousMonth, previousDate] = previousDay.split('-').map(Number);
  const todayUtc = Date.UTC(year, month - 1, day);
  const previousUtc = Date.UTC(previousYear, previousMonth - 1, previousDate);
  return Math.round((todayUtc - previousUtc) / 86400000);
}

export function isInQuietHours(minutes, start, end) {
  if (start === end) return false;
  return start < end
    ? minutes >= start && minutes < end
    : minutes >= start || minutes < end;
}

export function countStreakEndingYesterday(today, studyDates) {
  const dates = new Set(studyDates);
  let cursor = new Date(`${today}T00:00:00.000Z`);
  cursor.setUTCDate(cursor.getUTCDate() - 1);
  let streak = 0;
  while (dates.has(cursor.toISOString().slice(0, 10))) {
    streak++;
    cursor.setUTCDate(cursor.getUTCDate() - 1);
  }
  return streak;
}

export function chooseNotification({
  slot, today, lastStudyDate, studiedToday, studyDates = [],
  enabled = true, curiosityEnabled = true, quietHoursEnabled = true,
  quietStart = 22 * 60, quietEnd = 8 * 60, localMinutes = 9 * 60,
  alreadySent = new Set(), dailyCount = 0, language = 'en',
  question = '', topicId = '',
}) {
  if (!enabled || dailyCount >= DAILY_LIMIT) return null;
  if (quietHoursEnabled && isInQuietHours(localMinutes, quietStart, quietEnd)) return null;
  const languageCopy = COPY[language] ?? COPY.en;
  const inactiveDays = lastStudyDate ? localDateDifference(today, lastStudyDate) : null;
  const streak = countStreakEndingYesterday(today, studyDates);
  let type;
  let parts;
  if (slot === 'morning') {
    if (studiedToday) return null;
    if (lastStudyDate && inactiveDays >= 2) {
      type = 'missed_yesterday';
      parts = languageCopy.missed;
    } else {
      type = 'daily_lesson';
      parts = languageCopy.daily;
    }
  } else if (slot === 'afternoon') {
    if (!curiosityEnabled || !question) return null;
    type = 'afternoon_curiosity';
    parts = languageCopy.afternoon(question);
  } else if (slot === 'evening') {
    if (lastStudyDate && !studiedToday && inactiveDays >= 2 && inactiveDays <= 41) {
      type = 'inactivity';
      parts = languageCopy.inactive(inactiveDays);
    } else if (streak > 0 && !studiedToday) {
      type = 'streak_warning';
      parts = languageCopy.streak(streak);
    } else if (studiedToday && curiosityEnabled && question) {
      type = 'evening_curiosity';
      parts = languageCopy.evening(question);
    }
  }
  if (!type || alreadySent.has(type)) return null;
  return {type, title: parts[0], body: parts[1] ?? '', localDate: today, topicId};
}

export function deliveryIdempotencyKey(accountId, localDate, type) {
  return `${accountId}:${localDate}:${type}`;
}
