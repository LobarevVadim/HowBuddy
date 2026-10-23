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
