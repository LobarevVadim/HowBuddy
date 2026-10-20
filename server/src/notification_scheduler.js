import {chooseNotification, localClock} from './notification_policy.js';

const MINUTES = {morning: 9 * 60, afternoon: 12 * 60, evening: 18 * 60};
const SLOT_GRACE_MINUTES = 20;

export function slotDue(local) {
  const minutes = local.hour * 60 + local.minute;
  return Object.entries(MINUTES).find(([, target]) =>
    minutes >= target && minutes < target + SLOT_GRACE_MINUTES,
  )?.[0] ?? null;
}

export function reachableQuestionNodes(content) {
  const result = [];
  const visit = (id) => {
    const node = content.nodes[id];
    if (!node) return;
    result.push({id: node.id, question: node.question});
    for (const childId of node.children ?? []) visit(childId);
  };
  for (const rootId of content.roots ?? []) visit(rootId);
  return result;
}

export function createNotificationScheduler({
  pool,
  messaging,
  getLessonContent,
  emailSender = async () => ({sent: false, reason: 'email-not-configured'}),
  logger = console,
}) {
  let interval;
  let tickRunning = false;

  async function tick(now = new Date()) {
    if (!messaging || tickRunning) return {sent: 0, skipped: 'unavailable-or-busy'};
    tickRunning = true;
    let sent = 0;
    try {
      const result = await pool.query(
        `SELECT settings.account_id,
                settings.enabled,
                settings.curiosity_enabled,
                settings.quiet_hours_enabled,
                settings.quiet_start_minute,
                settings.quiet_end_minute,
                settings.time_zone,
                accounts.email AS account_email,
                COALESCE(accounts.preferred_language, 'en') AS language,
                array_agg(DISTINCT devices.token) AS tokens,
                COALESCE(history.study_dates, ARRAY[]::text[]) AS study_dates,
                COALESCE(deliveries.sent_types, ARRAY[]::text[]) AS sent_types,
                COALESCE(deliveries.daily_count, 0)::int AS daily_count
         FROM account_notification_settings settings
         JOIN accounts ON accounts.id = settings.account_id
         JOIN notification_devices devices ON devices.account_id = settings.account_id
         LEFT JOIN LATERAL (
           SELECT array_agg(study_date::text ORDER BY study_date DESC) AS study_dates
           FROM (
             SELECT DISTINCT (progress.completed_at AT TIME ZONE settings.time_zone)::date AS study_date
             FROM lesson_progress progress
             WHERE progress.account_id = settings.account_id
               AND progress.completed_at >= now() - interval '45 days'
           ) recent_days
         ) history ON true
         LEFT JOIN LATERAL (
           SELECT MAX((progress.completed_at AT TIME ZONE settings.time_zone)::date)::text AS last_study_date
           FROM lesson_progress progress
           WHERE progress.account_id = settings.account_id
         ) last_activity ON true
         LEFT JOIN LATERAL (
           SELECT array_agg(notification_type) AS sent_types, count(*)::int AS daily_count
           FROM notification_deliveries
           WHERE account_id = settings.account_id
             AND local_date = (now() AT TIME ZONE settings.time_zone)::date
         ) deliveries ON true
         WHERE settings.enabled = true
         GROUP BY settings.account_id, settings.enabled, settings.curiosity_enabled,
                  settings.quiet_hours_enabled, settings.quiet_start_minute,
                  settings.quiet_end_minute, settings.time_zone, accounts.email,
                  accounts.preferred_language,
                  history.study_dates, last_activity.last_study_date,
                  deliveries.sent_types, deliveries.daily_count`,
      );

      for (const user of result.rows) {
        const timeZone = user.time_zone || 'UTC';
        const clock = localClock(now, timeZone);
        const slot = slotDue(clock);
        if (!slot) continue;
        const studyDates = user.study_dates ?? [];
        const lastStudyDate = user.last_study_date ?? studyDates[0] ?? null;
        const studiedToday = studyDates.includes(clock.date);
        const sentTypes = new Set(user.sent_types ?? []);
        let question = null;
        if (slot !== 'morning' || user.curiosity_enabled) {
          const questions = reachableQuestionNodes(getLessonContent(user.language));
          if (questions.length) question = questions[Math.floor(Math.random() * questions.length)];
        }
        const plan = chooseNotification({
          slot,
          today: clock.date,
          lastStudyDate,
          studiedToday,
          studyDates,
          enabled: user.enabled,
          curiosityEnabled: user.curiosity_enabled,
          quietHoursEnabled: user.quiet_hours_enabled,
          quietStart: user.quiet_start_minute,
          quietEnd: user.quiet_end_minute,
          localMinutes: clock.hour * 60 + clock.minute,
          alreadySent: sentTypes,
          dailyCount: user.daily_count,
          language: user.language,
          question: question?.question ?? '',
          topicId: question?.id ?? '',
        });
        if (!plan) continue;
        const claimed = await claimDelivery(pool, user.account_id, clock.date, plan);
        if (!claimed) continue;
        try {
          const tokens = [...new Set(user.tokens ?? [])];
          let pushAccepted = false;
          for (let offset = 0; offset < tokens.length; offset += 500) {
            const batch = tokens.slice(offset, offset + 500);
            const response = await messaging.sendEachForMulticast({
              tokens: batch,
              notification: {title: plan.title, body: plan.body},
              data: {
                type: plan.type,
                topicId: plan.topicId,
                localDate: plan.localDate,
              },
              android: {priority: 'high', notification: {channelId: 'howbuddy_reminders', tag: `${clock.date}-${plan.type}`}},
              apns: {payload: {aps: {sound: 'default', threadId: 'howbuddy-reminders'}}},
              webpush: {headers: {Urgency: 'high'}, fcmOptions: {link: `/?notificationTopic=${encodeURIComponent(plan.topicId)}`}},
            });
            const expiredTokens = [];
            response.responses.forEach((item, index) => {
              if (!item.success && [
                'messaging/invalid-registration-token',
                'messaging/registration-token-not-registered',
              ].includes(item.error?.code)) expiredTokens.push(batch[index]);
            });
            if (expiredTokens.length) {
              await pool.query('DELETE FROM notification_devices WHERE token = ANY($1::text[])', [expiredTokens]);
            }
            if (response.successCount > 0) pushAccepted = true;
            else throw new Error('Firebase rejected every device token for this account.');
          }
          if (pushAccepted) {
            sent++;
            try {
              const emailResult = await emailSender({
                email: user.account_email,
                title: plan.title,
                body: plan.body,
                topicId: plan.topicId,
                type: plan.type,
                localDate: plan.localDate,
              });
              if (!emailResult.sent && emailResult.reason !== 'recipient-filtered') {
                logger.warn(`Notification email was not sent (${emailResult.reason ?? 'unknown reason'}).`);
              }
            } catch (error) {
              logger.error('Notification email send failed:', error.message);
            }
          }
          if (!tokens.length) await deleteDelivery(pool, user.account_id, clock.date, plan.type);
        } catch (error) {
          await deleteDelivery(pool, user.account_id, clock.date, plan.type);
          logger.error('Notification send failed:', error.message);
        }
      }
      return {sent};
    } catch (error) {
      logger.error('Notification scheduler tick failed:', error.message);
      return {sent, error: error.message};
    } finally {
      tickRunning = false;
    }
  }

  function start() {
    if (interval) return;
    void tick();
    interval = setInterval(() => void tick(), 60_000);
    interval.unref?.();
  }

  function stop() {
    if (interval) clearInterval(interval);
    interval = undefined;
  }

  return {tick, start, stop};
}

export async function claimDelivery(pool, accountId, localDate, plan) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT pg_advisory_xact_lock(hashtext($1), hashtext($2))', [accountId, localDate]);
    const count = await client.query(
      'SELECT count(*)::int AS value FROM notification_deliveries WHERE account_id = $1 AND local_date = $2::date',
      [accountId, localDate],
    );
    if (count.rows[0].value >= 3) {
      await client.query('ROLLBACK');
      return false;
    }
    const inserted = await client.query(
      `INSERT INTO notification_deliveries(account_id, local_date, notification_type, title, body, topic_id)
       VALUES ($1, $2::date, $3, $4, $5, $6)
       ON CONFLICT (account_id, local_date, notification_type) DO NOTHING
       RETURNING id`,
      [accountId, localDate, plan.type, plan.title, plan.body, plan.topicId],
    );
    await client.query('COMMIT');
    return inserted.rowCount === 1;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

async function deleteDelivery(pool, accountId, localDate, type) {
  await pool.query(
    'DELETE FROM notification_deliveries WHERE account_id = $1 AND local_date = $2::date AND notification_type = $3',
    [accountId, localDate, type],
  );
}
