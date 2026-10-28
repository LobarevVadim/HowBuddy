import {isValidTimeZone, localClock} from './notification_policy.js';

export function studyDate({timeZone, offsetMinutes = 0, now = new Date()}) {
  if (isValidTimeZone(timeZone)) return localClock(now, timeZone).date;
  const offset = Number(offsetMinutes);
  const safeOffset = Number.isInteger(offset) && Math.abs(offset) <= 840 ? offset : 0;
  return new Date(now.valueOf() + safeOffset * 60000).toISOString().slice(0, 10);
}
