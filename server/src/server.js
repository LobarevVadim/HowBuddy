import bcrypt from 'bcryptjs';
import cors from 'cors';
import dotenv from 'dotenv';
import express from 'express';
import {OAuth2Client} from 'google-auth-library';
import pg from 'pg';
import {createHmac, timingSafeEqual} from 'node:crypto';
import {existsSync, readFileSync} from 'node:fs';
import {getApps, initializeApp, cert} from 'firebase-admin/app';
import {getMessaging} from 'firebase-admin/messaging';
import {createNotificationScheduler} from './notification_scheduler.js';
import {createNotificationEmailSender} from './notification_email.js';
import {isValidTimeZone} from './notification_policy.js';
import {createSupportInbox, verifyResendWebhook, SUPPORT_INBOXES} from './support_inbox.js';

dotenv.config();

const app = express();
const port = Number(process.env.PORT ?? 3000);
const sessionSecret = process.env.SESSION_SECRET ?? '';
const googleWebClientId = process.env.GOOGLE_WEB_CLIENT_ID ?? '';
const googleOAuthClient = new OAuth2Client();
const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
});
const firebaseServiceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
let pushMessaging = null;
if (firebaseServiceAccountJson) {
  try {
    const serviceAccount = JSON.parse(firebaseServiceAccountJson);
    if (!getApps().length) initializeApp({credential: cert(serviceAccount)});
    pushMessaging = getMessaging();
  } catch (error) {
    console.error('Firebase Admin notifications are disabled: invalid service account JSON.', error.message);
  }
}
const notificationEmailSender = createNotificationEmailSender({
  apiKey: process.env.RESEND_API_KEY,
  from: process.env.NOTIFICATION_EMAIL_FROM,
});
const supportInbox = createSupportInbox({
  pool,
  apiKey: process.env.RESEND_API_KEY,
});
const notificationScheduler = createNotificationScheduler({
  pool,
  messaging: pushMessaging,
  getLessonContent,
  emailSender: notificationEmailSender,
});
const lessonContent = JSON.parse(
  readFileSync(new URL('../data/lesson_exercises.json', import.meta.url), 'utf8'),
);
const lessonContentByLanguage = new Map([['en', lessonContent]]);

function getLessonContent(language) {
  const code = ['fr', 'es', 'hi', 'ru'].includes(String(language))
    ? String(language)
    : 'en';
  if (lessonContentByLanguage.has(code)) return lessonContentByLanguage.get(code);
  const fileUrl = new URL(`../data/lesson_exercises_${code}.json`, import.meta.url);
  if (!existsSync(fileUrl)) return lessonContent;
  const localized = JSON.parse(readFileSync(fileUrl, 'utf8'));
  lessonContentByLanguage.set(code, localized);
  return localized;
}

app.use(cors());
app.post('/webhooks/resend', express.raw({type: 'application/json', limit: '2mb'}), async (request, response) => {
  const secret = process.env.RESEND_INBOUND_WEBHOOK_SECRET ?? '';
  if (!verifyResendWebhook(request.body ?? Buffer.alloc(0), request.headers, secret)) {
    return response.status(400).json({message: 'Invalid webhook signature.'});
  }
  try {
    const result = await supportInbox.handleWebhook(JSON.parse(request.body.toString('utf8')));
    return response.json({received: true, ...result});
  } catch (error) {
    console.error('Could not process inbound support email:', error.message);
    return response.status(500).json({message: 'Could not process inbound email.'});
  }
});
const standardJsonParser = express.json({limit: '1mb'});
app.use((request, response, next) => {
  if (request.method === 'POST' && /^\/admin\/conversations\/[^/]+\/reply\/?$/.test(request.path)) {
    return next();
  }
  return standardJsonParser(request, response, next);
});

app.get('/admin/session', requireAuth, requireAdmin, async (request, response) => {
  const result = await pool.query('SELECT full_name, email FROM accounts WHERE id = $1', [request.accountId]);
  return response.json({account: result.rows[0] ?? null, inboxes: SUPPORT_INBOXES});
});

app.get('/admin/overview', requireAuth, requireAdmin, async (_request, response) => {
  try {
    const result = await pool.query(`
      WITH people AS (
        SELECT a.created_at, a.last_active_at,
               COALESCE(NULLIF(s.time_zone, ''), 'UTC') AS time_zone
        FROM accounts a
        LEFT JOIN account_notification_settings s ON s.account_id = a.id
        WHERE a.auth_provider <> 'demo'
      )
      SELECT COUNT(*)::int AS total_users,
             COUNT(*) FILTER (WHERE created_at >= now() - interval '7 days')::int AS new_users_7d,
             COUNT(*) FILTER (WHERE created_at >= now() - interval '30 days')::int AS new_users_30d,
             COUNT(*) FILTER (
               WHERE last_active_at >= (
                 date_trunc('day', now() AT TIME ZONE time_zone) AT TIME ZONE time_zone
               )
             )::int AS dau,
             COUNT(*) FILTER (
               WHERE last_active_at >= (
                 ((now() AT TIME ZONE time_zone)::date - 29)::timestamp AT TIME ZONE time_zone
               )
             )::int AS mau
      FROM people`);
    const row = result.rows[0];
    const dau = Number(row.dau);
    const mau = Number(row.mau);
    return response.json({
      totalUsers: Number(row.total_users),
      newUsers7d: Number(row.new_users_7d),
      newUsers30d: Number(row.new_users_30d),
      dau,
      mau,
      dauMauPercent: mau ? Math.round((dau / mau) * 1000) / 10 : 0,
    });
  } catch (error) {
    console.error('Could not load admin overview:', error.message);
    return response.status(500).json({message: 'Could not load user overview.'});
  }
});

app.get('/admin/users', requireAuth, requireAdmin, async (request, response) => {
  const search = String(request.query.search ?? '').trim().slice(0, 200);
  const limit = Math.max(1, Math.min(100, Number.parseInt(request.query.limit, 10) || 25));
  const offset = Math.max(0, Number.parseInt(request.query.offset, 10) || 0);
  try {
    const result = await pool.query(
      `WITH filtered AS (
         SELECT id, full_name, email, created_at, last_active_at
         FROM accounts
         WHERE auth_provider <> 'demo'
           AND ($1 = '' OR full_name ILIKE $2 OR email ILIKE $2)
       )
       SELECT *, COUNT(*) OVER()::int AS total_count
       FROM filtered
       ORDER BY last_active_at DESC NULLS LAST, created_at DESC
       LIMIT $3 OFFSET $4`,
      [search, `%${search}%`, limit, offset],
    );
    return response.json({
      users: result.rows.map((row) => ({
        id: row.id,
        fullName: row.full_name,
        email: row.email,
        createdAt: row.created_at,
        lastActiveAt: row.last_active_at,
      })),
      total: result.rows.length ? Number(result.rows[0].total_count) : 0,
      limit,
      offset,
    });
  } catch (error) {
    console.error('Could not search admin users:', error.message);
    return response.status(500).json({message: 'Could not load users.'});
  }
});

app.get('/admin/learning-analytics', requireAuth, requireAdmin, async (_request, response) => {
  const analyticsTopics = [];
  const addTreeTopic = (topicId) => {
    const node = lessonContent.nodes[topicId];
    if (!node) return;
    analyticsTopics.push({
      id: node.id,
      title: node.question,
      level: Number(node.level) || 1,
      lesson_count: Number(node.lessonCount) || 1,
    });
    for (const childId of node.children ?? []) addTreeTopic(childId);
  };
  for (const rootId of lessonContent.roots) addTreeTopic(rootId);
  try {
    const [topicsResult, retentionResult] = await Promise.all([
      pool.query(
        `WITH topics AS (
           SELECT * FROM jsonb_to_recordset($1::jsonb)
             AS topic(id text, title text, level integer, lesson_count integer)
         ),
         lesson_activity AS (
           SELECT lp.topic_id,
                  COUNT(DISTINCT lp.account_id)::int AS interested_users,
                  COUNT(DISTINCT lp.account_id) FILTER (
                    WHERE lp.lesson_id = 'lesson-' || topics.lesson_count::text
                  )::int AS last_lesson_users
           FROM lesson_progress lp
           JOIN accounts a ON a.id = lp.account_id
           JOIN topics ON topics.id = lp.topic_id
           WHERE a.auth_provider <> 'demo'
           GROUP BY lp.topic_id, topics.lesson_count
         )
         SELECT topics.id, topics.title, topics.level, topics.lesson_count,
                COALESCE(activity.interested_users, 0)::int AS interested_users,
                COALESCE(activity.last_lesson_users, 0)::int AS last_lesson_users
         FROM topics
         LEFT JOIN lesson_activity activity ON activity.topic_id = topics.id`,
        [JSON.stringify(analyticsTopics)],
      ),
      pool.query(`
        WITH cohort AS (
          SELECT a.id,
                 (a.created_at AT TIME ZONE COALESCE(NULLIF(s.time_zone, ''), 'UTC'))::date AS registration_day,
                 (now() AT TIME ZONE COALESCE(NULLIF(s.time_zone, ''), 'UTC'))::date AS local_today
          FROM accounts a
          LEFT JOIN account_notification_settings s ON s.account_id = a.id
          WHERE a.auth_provider <> 'demo'
        ),
        offsets(day_number) AS (VALUES (1), (7), (30))
        SELECT offsets.day_number,
               COUNT(*) FILTER (
                 WHERE cohort.registration_day + offsets.day_number <= cohort.local_today
               )::int AS eligible_users,
               COUNT(*) FILTER (
                 WHERE cohort.registration_day + offsets.day_number <= cohort.local_today
                   AND EXISTS (
                     SELECT 1 FROM study_days activity
                     WHERE activity.account_id = cohort.id
                       AND activity.study_date = cohort.registration_day + offsets.day_number
                   )
               )::int AS retained_users
        FROM cohort CROSS JOIN offsets
        GROUP BY offsets.day_number ORDER BY offsets.day_number`),
    ]);
    const topics = topicsResult.rows.map((row) => ({
      id: row.id,
      title: row.title,
      level: Number(row.level),
      lessonCount: Number(row.lesson_count),
      interestedUsers: Number(row.interested_users),
      lastLessonUsers: Number(row.last_lesson_users),
    }));
    const retention = retentionResult.rows.map((row) => ({
      day: Number(row.day_number),
      eligibleUsers: Number(row.eligible_users),
      retainedUsers: Number(row.retained_users),
      ratePercent: Number(row.eligible_users)
        ? Math.round((Number(row.retained_users) / Number(row.eligible_users)) * 1000) / 10
        : 0,
    }));
    const totals = await pool.query(
      `SELECT COUNT(DISTINCT a.id)::int AS users,
              COUNT(lp.lesson_id)::int AS lessons_completed
       FROM accounts a
       LEFT JOIN lesson_progress lp ON lp.account_id = a.id
       WHERE a.auth_provider <> 'demo'`,
    );
    const totalUsers = Number(totals.rows[0].users);
    const topicsWithRates = topics.map((topic) => ({
      ...topic,
      interestRatePercent: totalUsers
        ? Math.round((topic.interestedUsers / totalUsers) * 1000) / 10
        : 0,
      completionRatePercent: topic.interestedUsers
        ? Math.round((topic.lastLessonUsers / topic.interestedUsers) * 1000) / 10
        : 0,
    }));
    return response.json({
      lessonsCompleted: Number(totals.rows[0].lessons_completed),
      topics: topicsWithRates,
      retention,
    });
  } catch (error) {
    console.error('Could not load learning analytics:', error.message);
    return response.status(500).json({message: 'Could not load learning analytics.'});
  }
});

app.get('/admin/conversations', requireAuth, requireAdmin, async (request, response) => {
  try {
    return response.json({conversations: await supportInbox.list({
      search: String(request.query.search ?? ''),
      inbox: String(request.query.inbox ?? ''),
    })});
  } catch (error) {
    console.error('Could not load support inbox:', error.message);
    return response.status(500).json({message: 'Could not load support inbox.'});
  }
});

app.get('/admin/conversations/:id', requireAuth, requireAdmin, async (request, response) => {
  try {
    const conversation = await supportInbox.getConversation(request.params.id);
    if (!conversation) return response.status(404).json({message: 'Conversation not found.'});
    return response.json({conversation});
  } catch (error) {
    console.error('Could not load support conversation:', error.message);
    return response.status(500).json({message: 'Could not load conversation.'});
  }
});

app.post('/admin/conversations/:id/read', requireAuth, requireAdmin, async (request, response) => {
  try {
    const updated = await supportInbox.markRead(request.params.id);
    return response.status(updated ? 200 : 404).json({read: updated});
  } catch (error) {
    console.error('Could not update support read status:', error.message);
    return response.status(500).json({message: 'Could not update read status.'});
  }
});

app.post('/admin/conversations/:id/reply', requireAuth, requireAdmin, express.json({limit: '36mb'}), async (request, response) => {
  try {
    return response.json(await supportInbox.reply(
      request.params.id, request.body.text, request.body.attachments,
    ));
  } catch (error) {
    const status = error.message === 'Conversation not found.' ? 404
      : /Write a reply|Invalid support inbox|[Aa]ttach/.test(error.message) ? 400 : 502;
    return response.status(status).json({message: error.message || 'Could not send reply.'});
  }
});

app.get('/admin/attachments/:id', requireAuth, requireAdmin, async (request, response) => {
  try {
    const attachment = await supportInbox.attachmentUrl(request.params.id);
    if (!attachment) return response.status(404).json({message: 'Attachment not found.'});
    return response.json(attachment);
  } catch (error) {
    console.error('Could not retrieve support attachment:', error.message);
    return response.status(502).json({message: 'Could not retrieve attachment.'});
  }
});

app.get('/health', async (_request, response) => {
  try {
    await pool.query('SELECT 1');
    response.json({ok: true, database: 'connected'});
  } catch (_error) {
    response.status(503).json({ok: false, database: 'unavailable'});
  }
});

app.get('/onboarding/topics', (request, response) => {
  response.json({topics: rootTopics(getLessonContent(request.query.language))});
});

app.get('/gamification', requireAuth, async (request, response) => {
  const accountId = request.accountId;
  try {
    return response.json(await getGameState(accountId, clientStudyDate(request)));
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not load game progress.'});
  }
});

app.post('/gamification/streak-goal', requireAuth, async (request, response) => {
  const goalDays = Number(request.body?.goalDays);
  if (![7, 14, 30].includes(goalDays)) {
    return response.status(400).json({message: 'Choose a 7, 14, or 30-day goal.'});
  }
  const today = clientStudyDate(request);
  try {
    await ensureGameRow(request.accountId);
    await pool.query(
      `UPDATE account_gamification
       SET streak_goal_days = $2, streak_goal_started_at = $3::date
       WHERE account_id = $1`,
      [request.accountId, goalDays, today],
    );
    return response.json(await getGameState(request.accountId, today));
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not save your streak goal.'});
  }
});

app.post('/gamification/consume-heart', requireAuth, async (request, response) => {
  const accountId = request.accountId;
  try {
    await ensureGameRow(accountId);
    await refreshHearts(accountId);
    await pool.query('UPDATE accounts SET last_active_at = now() WHERE id = $1', [accountId]);
    const result = await pool.query(
      `UPDATE account_gamification
       SET hearts = hearts - 1,
           heart_recharge_at = CASE
             WHEN hearts = 5 THEN now() + interval '3 hours'
             ELSE COALESCE(heart_recharge_at, now() + interval '3 hours')
           END
       WHERE account_id = $1 AND hearts > 0 RETURNING hearts`,
      [accountId],
    );
    return response.json({
      lessonAllowed: result.rowCount === 1,
      ...await getGameState(accountId, clientStudyDate(request)),
    });
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not use a lesson heart.'});
  }
});

app.post('/gamification/heart-video', requireAuth, async (request, response) => {
  const accountId = request.accountId;
  try {
    await ensureGameRow(accountId);
    await refreshHearts(accountId);
    await pool.query(
      `UPDATE account_gamification
       SET hearts = LEAST(5, hearts + 1),
           heart_recharge_at = CASE
             WHEN hearts + 1 >= 5 THEN NULL
             ELSE COALESCE(heart_recharge_at, now() + interval '3 hours')
           END
       WHERE account_id = $1`,
      [accountId],
    );
    return response.json(await getGameState(accountId, clientStudyDate(request)));
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not restore a heart.'});
  }
});

app.post('/gamification/emerald-video', requireAuth, async (request, response) => {
  const accountId = request.accountId;
  try {
    await ensureGameRow(accountId);
    await pool.query(
      'UPDATE account_gamification SET emeralds = emeralds + 25 WHERE account_id = $1',
      [accountId],
    );
    return response.json(await getGameState(accountId, clientStudyDate(request)));
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not add emeralds.'});
  }
});

app.post('/gamification/xp-boost', requireAuth, async (request, response) => {
  const accountId = request.accountId;
  const minutes = Number(request.body.durationMinutes);
  const price = new Map([[60, 80], [30, 45], [10, 20]]).get(minutes);
  if (!price) {
    return response.status(400).json({message: 'That XP boost is not available.'});
  }
  try {
    await ensureGameRow(accountId);
    const result = await pool.query(
      `UPDATE account_gamification
       SET emeralds = emeralds - $2,
           xp_boost_until = GREATEST(COALESCE(xp_boost_until, now()), now()) + ($3 * interval '1 minute')
       WHERE account_id = $1 AND emeralds >= $2
       RETURNING account_id`,
      [accountId, price, minutes],
    );
    if (result.rowCount !== 1) {
      return response.status(400).json({message: 'You do not have enough emeralds.'});
    }
    return response.json(await getGameState(accountId, clientStudyDate(request)));
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not buy the XP boost.'});
  }
});

app.post('/auth/register', async (request, response) => {
  const fullName = String(request.body.fullName ?? '').trim();
  const email = String(request.body.email ?? '').trim().toLowerCase();
  const password = String(request.body.password ?? '');

  if (fullName.length < 2 || !email.includes('@') || password.length < 8) {
    return response.status(400).json({message: 'Please complete all fields correctly.'});
  }

  const passwordHash = await bcrypt.hash(password, 12);

  try {
    const result = await pool.query(
      `INSERT INTO accounts (full_name, email, password_hash, auth_provider, last_active_at)
       VALUES ($1, $2, $3, 'password', now())
       RETURNING id, full_name, email, avatar_palette_index, glasses_accessory_index,
                 avatar_emoji,
                 preferred_language, age_years`,
      [fullName, email, passwordHash],
    );

    return response.status(201).json({
      account: toAccount(result.rows[0]),
      sessionToken: issueSession(result.rows[0].id),
    });
  } catch (error) {
    if (error.code === '23505') {
      return response.status(409).json({message: 'An account already exists for this email.'});
    }

    console.error(error);
    return response.status(500).json({message: 'Could not create account.'});
  }
});

app.post('/auth/google', async (request, response) => {
  if (!googleWebClientId) {
    return response.status(503).json({message: 'Google sign-in is not configured on the server.'});
  }

  const idToken = String(request.body.idToken ?? '').trim();
  const allowRegistration = request.body.allowRegistration === true;
  if (!idToken || idToken.length > 10000) {
    return response.status(400).json({message: 'A valid Google sign-in token is required.'});
  }

  let googleUser;
  try {
    const ticket = await googleOAuthClient.verifyIdToken({
      idToken,
      audience: googleWebClientId,
    });
    googleUser = ticket.getPayload();
  } catch (_error) {
    return response.status(401).json({message: 'Google sign-in could not be verified.'});
  }
  if (!googleUser?.sub || !googleUser.email || googleUser.email_verified !== true) {
    return response.status(401).json({message: 'Google did not verify this email address.'});
  }

  try {
    const email = googleUser.email.toLowerCase();
    const existing = await pool.query(
      `SELECT id, full_name, email, provider_subject, avatar_palette_index,
              glasses_accessory_index, avatar_emoji,
              preferred_language, age_years
       FROM accounts WHERE provider_subject = $1 OR email = $2 LIMIT 1`,
      [googleUser.sub, email],
    );

    let account = existing.rows[0];
    let isNewUser = false;
    if (account) {
      if (account.provider_subject && account.provider_subject !== googleUser.sub) {
        return response.status(409).json({message: 'This email is connected to a different sign-in method.'});
      }
      if (!account.provider_subject) {
        const linked = await pool.query(
          `UPDATE accounts SET provider_subject = $1
           WHERE id = $2 AND provider_subject IS NULL
           RETURNING id, full_name, email, provider_subject, avatar_palette_index,
                     glasses_accessory_index, avatar_emoji,
                     preferred_language, age_years`,
          [googleUser.sub, account.id],
        );
        account = linked.rows[0] ?? account;
      }
    } else {
      if (!allowRegistration) {
        return response.status(404).json({message: 'No HowBuddy account uses this Google account. Sign up first.'});
      }
      const name = String(googleUser.name ?? '').trim() || email.split('@')[0];
      try {
        const created = await pool.query(
          `INSERT INTO accounts (full_name, email, auth_provider, provider_subject)
           VALUES ($1, $2, 'google', $3)
           RETURNING id, full_name, email, provider_subject, avatar_palette_index,
                     glasses_accessory_index, avatar_emoji,
                     preferred_language, age_years`,
          [name, email, googleUser.sub],
        );
        account = created.rows[0];
        isNewUser = true;
      } catch (error) {
        if (error.code !== '23505') throw error;
        const raced = await pool.query(
          `SELECT id, full_name, email, provider_subject, avatar_palette_index,
                  glasses_accessory_index, avatar_emoji,
                  preferred_language, age_years
           FROM accounts WHERE provider_subject = $1 OR email = $2 LIMIT 1`,
          [googleUser.sub, email],
        );
        account = raced.rows[0];
        if (!account || (account.provider_subject && account.provider_subject !== googleUser.sub)) {
          return response.status(409).json({message: 'An account already exists for this email.'});
        }
        if (!account.provider_subject) {
          const linked = await pool.query(
            `UPDATE accounts SET provider_subject = $1
             WHERE id = $2 AND provider_subject IS NULL
             RETURNING id, full_name, email, provider_subject, avatar_palette_index,
                       glasses_accessory_index, avatar_emoji,
                       preferred_language, age_years`,
            [googleUser.sub, account.id],
          );
          account = linked.rows[0] ?? account;
        }
      }
    }

    await pool.query('UPDATE accounts SET last_active_at = now() WHERE id = $1', [account.id]);
    return response.status(isNewUser ? 201 : 200).json({
      account: toAccount(account),
      sessionToken: issueSession(account.id),
      isNewUser,
    });
  } catch (error) {
    console.error('Google sign-in failed:', error.message);
    return response.status(500).json({message: 'Could not complete Google sign-in.'});
  }
});

app.get('/lessons/tree', requireAuth, async (request, response) => {
  try {
    const content = await getAccountLessonContent(request);
    const topic = findTopic(String(request.query.topic ?? content.roots[0]), content);
    if (!topic) return response.status(404).json({message: 'This lesson topic was not found.'});
    const levels = await buildLessonLevels(topic, request.accountId, content);
    return response.json({
      topic,
      levels,
      nextQuestions: getNextQuestions(topic.id, content),
      isSelectableTopic: content.nodes[topic.id].level > 1,
    });
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not load lesson progress.'});
  }
});

app.get('/account/last-topic', requireAuth, async (request, response) => {
  try {
    const result = await pool.query(
      'SELECT last_topic_id FROM accounts WHERE id = $1',
      [request.accountId],
    );
    return response.json({topicId: result.rows[0]?.last_topic_id ?? null});
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not load your last lesson topic.'});
  }
});

app.put('/account/last-topic', requireAuth, async (request, response) => {
  const topicId = String(request.body.topicId ?? '').trim();
  if (!findTopic(topicId)) {
    return response.status(400).json({message: 'This lesson topic was not found.'});
  }
  try {
    await pool.query(
      'UPDATE accounts SET last_topic_id = $1 WHERE id = $2',
      [topicId, request.accountId],
    );
    return response.json({ok: true});
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not save your last lesson topic.'});
  }
});

app.put('/account/avatar-palette', requireAuth, async (request, response) => {
  const paletteIndex = Number(request.body.paletteIndex);
  if (!Number.isInteger(paletteIndex) || paletteIndex < 0 || paletteIndex > 20) {
    return response.status(400).json({message: 'Choose one of the available avatar palettes.'});
  }
  try {
    await pool.query(
      'UPDATE accounts SET avatar_palette_index = $1 WHERE id = $2',
      [paletteIndex, request.accountId],
    );
    return response.json({avatarPaletteIndex: paletteIndex});
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not save your avatar colors.'});
  }
});

app.put('/account/avatar-glasses', requireAuth, async (request, response) => {
  const accessoryIndex = Number(request.body.accessoryIndex);
  if (!Number.isInteger(accessoryIndex) || accessoryIndex < 0 || accessoryIndex > 16) {
    return response.status(400).json({message: 'Choose one of the available glasses options.'});
  }
  try {
    await pool.query(
      'UPDATE accounts SET glasses_accessory_index = $1 WHERE id = $2',
      [accessoryIndex, request.accountId],
    );
    return response.json({glassesAccessoryIndex: accessoryIndex});
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not save your glasses.'});
  }
});

app.put('/account/avatar-emoji', requireAuth, async (request, response) => {
  const emoji = String(request.body.emoji ?? '').trim();
  if (emoji.length > 32 || /[<>]/.test(emoji)) {
    return response.status(400).json({message: 'Choose a valid avatar emoji.'});
  }
  try {
    await pool.query(
      'UPDATE accounts SET avatar_emoji = $1 WHERE id = $2',
      [emoji, request.accountId],
    );
    return response.json({avatarEmoji: emoji});
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not save your avatar emoji.'});
  }
});

app.put('/account/preferences', requireAuth, async (request, response) => {
  const preferredLanguage = String(request.body.preferredLanguage ?? '');
  const ageYears = Number(request.body.ageYears);
  if (!['en', 'fr', 'es', 'hi', 'ru'].includes(preferredLanguage)) {
    return response.status(400).json({message: 'Choose a supported language.'});
  }
  if (!Number.isInteger(ageYears) || ageYears < 1 || ageYears > 120) {
    return response.status(400).json({message: 'Choose an age between 1 and 120.'});
  }
  try {
    await pool.query(
      'UPDATE accounts SET preferred_language = $1, age_years = $2 WHERE id = $3',
      [preferredLanguage, ageYears, request.accountId],
    );
    return response.json({preferredLanguage, ageYears});
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not save your preferences.'});
  }
});

app.get('/account/notifications/preferences', requireAuth, async (request, response) => {
  try {
    await ensureNotificationSettings(request.accountId);
    const result = await pool.query(
      `SELECT enabled, curiosity_enabled, quiet_hours_enabled,
              quiet_start_minute, quiet_end_minute
       FROM account_notification_settings WHERE account_id = $1`,
      [request.accountId],
    );
    return response.json({preferences: notificationPreferencesJson(result.rows[0])});
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not load notification preferences.'});
  }
});

app.put('/account/notifications/preferences', requireAuth, async (request, response) => {
  const enabled = request.body.enabled === true;
  const curiosityEnabled = request.body.curiosityEnabled !== false;
  const quietHoursEnabled = request.body.quietHoursEnabled !== false;
  const quietStartMinute = Number(request.body.quietStartMinute);
  const quietEndMinute = Number(request.body.quietEndMinute);
  if (![quietStartMinute, quietEndMinute].every((minute) => Number.isInteger(minute) && minute >= 0 && minute < 1440)) {
    return response.status(400).json({message: 'Choose valid quiet-hour times.'});
  }
  try {
    await pool.query(
      `INSERT INTO account_notification_settings
         (account_id, enabled, curiosity_enabled, quiet_hours_enabled,
          quiet_start_minute, quiet_end_minute)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (account_id) DO UPDATE SET
         enabled = EXCLUDED.enabled,
         curiosity_enabled = EXCLUDED.curiosity_enabled,
         quiet_hours_enabled = EXCLUDED.quiet_hours_enabled,
         quiet_start_minute = EXCLUDED.quiet_start_minute,
         quiet_end_minute = EXCLUDED.quiet_end_minute,
         updated_at = now()`,
      [request.accountId, enabled, curiosityEnabled, quietHoursEnabled, quietStartMinute, quietEndMinute],
    );
    return response.json({preferences: {
      enabled, curiosityEnabled, quietHoursEnabled, quietStartMinute, quietEndMinute,
    }});
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not save notification preferences.'});
  }
});

app.post('/account/notifications/device', requireAuth, async (request, response) => {
  const token = String(request.body.token ?? '').trim();
  const platform = String(request.body.platform ?? '');
  const language = String(request.body.language ?? 'en');
  const timeZone = String(request.body.timeZone ?? 'UTC');
  if (!token || token.length > 4096 || !['android', 'ios', 'web'].includes(platform)) {
    return response.status(400).json({message: 'Invalid notification device.'});
  }
  if (!['en', 'fr', 'es', 'hi', 'ru'].includes(language) || !isValidTimeZone(timeZone)) {
    return response.status(400).json({message: 'Invalid language or time zone.'});
  }
  try {
    await ensureNotificationSettings(request.accountId);
    await pool.query(
      `INSERT INTO notification_devices(token, account_id, platform, language)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (token) DO UPDATE SET account_id = EXCLUDED.account_id,
         platform = EXCLUDED.platform, language = EXCLUDED.language, last_seen_at = now()`,
      [token, request.accountId, platform, language],
    );
    await pool.query(
      `UPDATE account_notification_settings SET time_zone = $1, updated_at = now()
       WHERE account_id = $2`,
      [timeZone, request.accountId],
    );
    return response.json({registered: true});
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not register this notification device.'});
  }
});

app.delete('/account/notifications/device', requireAuth, async (request, response) => {
  const token = String(request.body.token ?? '').trim();
  if (!token) return response.status(400).json({message: 'Notification token is required.'});
  try {
    await pool.query(
      'DELETE FROM notification_devices WHERE account_id = $1 AND token = $2',
      [request.accountId, token],
    );
    return response.json({unregistered: true});
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not unregister this notification device.'});
  }
});

app.post('/account/notifications/test', requireAuth, async (request, response) => {
  if (!pushMessaging) {
    return response.status(503).json({message: 'Push notifications are not configured on the server.'});
  }
  try {
    const [devices, account] = await Promise.all([
      pool.query('SELECT token FROM notification_devices WHERE account_id = $1', [request.accountId]),
      pool.query('SELECT email, preferred_language FROM accounts WHERE id = $1', [request.accountId]),
    ]);
    const tokens = devices.rows.map((row) => row.token);
    if (!tokens.length) return response.status(400).json({message: 'Enable notifications on this device first.'});
    const language = account.rows[0]?.preferred_language ?? 'en';
    const testText = {
      en: ['HowBuddy test', 'Your notifications are ready!'],
      fr: ['Test HowBuddy', 'Tes notifications sont prêtes !'],
      es: ['Prueba de HowBuddy', '¡Tus notificaciones están listas!'],
      ru: ['Тест HowBuddy', 'Уведомления готовы!'],
      hi: ['HowBuddy परीक्षण', 'आपकी सूचनाएँ तैयार हैं!'],
    }[language] ?? ['HowBuddy test', 'Your notifications are ready!'];
    let sent = 0;
    for (let offset = 0; offset < tokens.length; offset += 500) {
      const result = await pushMessaging.sendEachForMulticast({
        tokens: tokens.slice(offset, offset + 500),
        notification: {title: testText[0], body: testText[1]},
        data: {type: 'test', topicId: ''},
      });
      sent += result.successCount;
    }
    let emailSent = false;
    if (sent > 0) {
      const emailResult = await notificationEmailSender({
        email: account.rows[0]?.email,
        title: testText[0],
        body: testText[1],
        type: 'test',
      });
      emailSent = emailResult.sent;
    }
    return response.json({sent, emailSent});
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not send the test notification.'});
  }
});

app.post('/notifications/tick', async (request, response) => {
  const secret = process.env.NOTIFICATION_CRON_SECRET ?? '';
  const supplied = String(request.get('X-Notification-Cron-Secret') ?? '');
  const secretBytes = Buffer.from(secret);
  const suppliedBytes = Buffer.from(supplied);
  const authorized = secretBytes.length > 0 &&
    secretBytes.length === suppliedBytes.length &&
    timingSafeEqual(secretBytes, suppliedBytes);
  if (!authorized) return response.status(secret ? 401 : 503).json({message: 'Scheduler is not authorized.'});
  return response.json(await notificationScheduler.tick());
});

app.get('/lessons/exercises', async (request, response) => {
  const topicId = String(request.query.topic ?? '').trim();
  const lessonId = String(request.query.lesson ?? 'lesson-1').trim();
  try {
    const content = await getAccountLessonContent(request);
    const topicContent = content.nodes[topicId];
    if (!topicContent) {
      return response.status(404).json({message: 'No exercises are available for this topic.'});
    }
    const lessonNumber = Number(lessonId.replace('lesson-', ''));
    const extraNodeId = topicContent.extraLessons?.[lessonNumber - 2];
    const lesson = lessonNumber === 1 ? topicContent : content.nodes[extraNodeId];
    if (!lesson || !Number.isInteger(lessonNumber) || lessonNumber < 1) {
      return response.status(404).json({message: 'This lesson is not available.'});
    }
    return response.json({topic: topicId, content: lesson.content, exercises: lesson.exercises});
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not load lesson exercises.'});
  }
});

app.post('/lessons/complete', requireAuth, async (request, response) => {
  const topicId = String(request.body.topicId ?? '').trim();
  const lessonId = String(request.body.lessonId ?? '').trim();
  const accountId = request.accountId;
  const correctAnswers = Number(request.body.correctAnswers);
  const exerciseCount = Number(request.body.exerciseCount);
  const durationSeconds = Number(request.body.durationSeconds ?? 0);
  const topic = findTopic(topicId);

  if (!topic) return response.status(404).json({message: 'This lesson topic was not found.'});
  if (!lessonId) {
    return response.status(400).json({message: 'Lesson is required.'});
  }
  if (
    !Number.isInteger(correctAnswers) ||
    !Number.isInteger(exerciseCount) ||
    !Number.isInteger(durationSeconds) ||
    exerciseCount < 1 ||
    exerciseCount > 100 ||
    correctAnswers < 0 ||
    correctAnswers > exerciseCount ||
    durationSeconds < 0 ||
    durationSeconds > 604800
  ) {
    return response.status(400).json({message: 'Lesson score is invalid.'});
  }

  const lessonNumber = Number(lessonId.replace('lesson-', ''));
  if (!Number.isInteger(lessonNumber) || lessonNumber < 1 || lessonNumber > Math.min(topic.lessonCount, 20)) {
    return response.status(400).json({message: 'This lesson is not available.'});
  }

  const answerXp = (correctAnswers * 5) + ((exerciseCount - correctAnswers) * 2);

  try {
    await ensureGameRow(accountId);
    await pool.query(
      `INSERT INTO lesson_progress (account_id, topic_id, lesson_id)
       VALUES ($1, $2, $3) ON CONFLICT (account_id, topic_id, lesson_id) DO NOTHING`,
      [accountId, topic.id, lessonId],
    );
    const completionCount = await pool.query(
      'SELECT COUNT(*)::int AS count FROM lesson_progress WHERE account_id = $1 AND topic_id = $2',
      [accountId, topic.id],
    );
    const topicCompleted = completionCount.rows[0].count >= Math.min(topic.lessonCount, 20);
    await pool.query(
      'INSERT INTO study_days (account_id, study_date) VALUES ($1, $2::date) ON CONFLICT DO NOTHING',
      [accountId, clientStudyDate(request)],
    );
    const game = await pool.query(
      'SELECT xp_boost_until > now() AS boost_active FROM account_gamification WHERE account_id = $1',
      [accountId],
    );
    const timeMultiplier = durationSeconds > 180 ? 0.8 : 1;
    const potionMultiplier = game.rows[0].boost_active ? 2 : 1;
    const earnedXp = Math.round(answerXp * timeMultiplier * potionMultiplier);
    const insertResult = await pool.query(
      `INSERT INTO lesson_xp (account_id, topic_id, lesson_id, xp)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (account_id, topic_id, lesson_id) DO NOTHING`,
      [accountId, topic.id, lessonId, earnedXp],
    );
    const awardedXp = insertResult.rowCount === 1 ? earnedXp : 0;
    const totals = await pool.query(
      'SELECT COALESCE(SUM(xp), 0)::int AS total_xp FROM lesson_xp WHERE account_id = $1',
      [accountId],
    );
    await pool.query('UPDATE accounts SET last_active_at = now() WHERE id = $1', [accountId]);
    return response.json({
      ok: true,
      topicCompleted,
      earnedXp: awardedXp,
      totalXp: totals.rows[0].total_xp,
    });
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not save lesson progress.'});
  }
});

app.get('/xp/weekly', requireAuth, async (request, response) => {
  const accountId = request.accountId;
  const today = clientStudyDate(request);
  const offsetMinutes = clientTimezoneOffset(request);
  const localDateSql = "((created_at AT TIME ZONE 'UTC') + ($2::int * interval '1 minute'))::date";

  try {
    const [totals, daily, leaderboardRows] = await Promise.all([
      pool.query(
        'SELECT COALESCE(SUM(xp), 0)::int AS total_xp FROM lesson_xp WHERE account_id = $1',
        [accountId],
      ),
      pool.query(
        `SELECT ${localDateSql}::text AS date,
                SUM(xp)::int AS xp
         FROM lesson_xp
         WHERE account_id = $1
           AND ${localDateSql} BETWEEN ($3::date - 6) AND $3::date
         GROUP BY ${localDateSql}
         ORDER BY date`,
        [accountId, offsetMinutes, today],
      ),
      pool.query(
        `WITH account_totals AS (
           SELECT accounts.id, accounts.full_name, accounts.avatar_palette_index,
                  accounts.glasses_accessory_index, accounts.avatar_emoji,
                  accounts.created_at,
                  COALESCE(SUM(lesson_xp.xp), 0)::int AS xp
           FROM accounts
           LEFT JOIN lesson_xp ON lesson_xp.account_id = accounts.id
           GROUP BY accounts.id
         ), ranked AS (
           SELECT id, full_name, avatar_palette_index, glasses_accessory_index,
                  avatar_emoji, xp,
                  ROW_NUMBER() OVER (
                    ORDER BY xp DESC, created_at ASC, lower(full_name), id
                  )::int AS place
           FROM account_totals
         )
         SELECT id, full_name AS name, avatar_palette_index, glasses_accessory_index,
                avatar_emoji, xp, place
         FROM ranked
         WHERE place <= 10 OR id = $1
         ORDER BY place`,
        [accountId],
      ),
    ]);
    const xpByDate = new Map(daily.rows.map((row) => [row.date, row.xp]));
    const todayDate = new Date(`${today}T00:00:00.000Z`);
    const days = Array.from({length: 7}, (_item, index) => {
      const date = new Date(todayDate.valueOf() - (6 - index) * 86400000)
        .toISOString().slice(0, 10);
      return {date, xp: xpByDate.get(date) ?? 0};
    });
    const currentUser = leaderboardRows.rows.find((row) => row.id === accountId);
    const leaderboard = leaderboardRows.rows
      .filter((row) => row.place <= 10)
      .map(({id, name, xp, place, avatar_palette_index, glasses_accessory_index, avatar_emoji}) => ({
        name,
        xp,
        place,
        isYou: id === accountId,
        avatarPaletteIndex: avatar_palette_index,
        glassesAccessoryIndex: glasses_accessory_index,
        avatarEmoji: avatar_emoji,
      }));
    const yourPlace = currentUser?.place > 10
      ? {
          name: currentUser.name,
          xp: currentUser.xp,
          place: currentUser.place,
          isYou: true,
          avatarPaletteIndex: currentUser.avatar_palette_index,
          glassesAccessoryIndex: currentUser.glasses_accessory_index,
          avatarEmoji: currentUser.avatar_emoji,
        }
      : null;
    return response.json({totalXp: totals.rows[0].total_xp, days, leaderboard, yourPlace});
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not load weekly XP.'});
  }
});

app.get('/notepad/tree', requireAuth, async (request, response) => {
  const accountId = request.accountId;
  try {
    return response.json({
      tree: await buildNotepadTree(accountId, await getAccountLessonContent(request)),
    });
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not load lesson progress.'});
  }
});

app.post('/auth/login', async (request, response) => {
  const identifier = String(request.body.identifier ?? '').trim().toLowerCase();
  const password = String(request.body.password ?? '');

  if (identifier.length === 0 || password.length < 8) {
    return response.status(400).json({message: 'Enter your login details.'});
  }

  const result = await pool.query(
    `SELECT id, full_name, email, password_hash, avatar_palette_index,
            glasses_accessory_index, avatar_emoji,
            preferred_language, age_years
     FROM accounts
     WHERE email = $1 OR username = $1
     LIMIT 1`,
    [identifier],
  );

  const account = result.rows[0];
  if (!account || !account.password_hash || !(await bcrypt.compare(password, account.password_hash))) {
    return response.status(401).json({message: 'Invalid email, username, or password.'});
  }

  await pool.query('UPDATE accounts SET last_active_at = now() WHERE id = $1', [account.id]);
  return response.json({
    account: toAccount(account),
    sessionToken: issueSession(account.id),
  });
});

function issueSession(accountId) {
  const header = encodeBase64Url(JSON.stringify({alg: 'HS256', typ: 'JWT'}));
  const payload = encodeBase64Url(JSON.stringify({
    sub: accountId,
    exp: Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60),
  }));
  const unsigned = `${header}.${payload}`;
  const signature = createHmac('sha256', sessionSecret).update(unsigned).digest('base64url');
  return `${unsigned}.${signature}`;
}

function encodeBase64Url(value) {
  return Buffer.from(value).toString('base64url');
}

function requireAuth(request, response, next) {
  const token = String(request.headers.authorization ?? '').replace(/^Bearer\s+/i, '');
  const parts = token.split('.');
  if (parts.length !== 3 || !sessionSecret) {
    return response.status(401).json({message: 'Please sign in again.'});
  }
  const unsigned = `${parts[0]}.${parts[1]}`;
  const expected = createHmac('sha256', sessionSecret).update(unsigned).digest();
  let actual;
  try {
    actual = Buffer.from(parts[2], 'base64url');
  } catch (_error) {
    return response.status(401).json({message: 'Your session is invalid. Please sign in again.'});
  }
  if (actual.length !== expected.length || !timingSafeEqual(actual, expected)) {
    return response.status(401).json({message: 'Your session is invalid. Please sign in again.'});
  }
  try {
    const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
    if (typeof payload.sub !== 'string' || payload.exp <= Date.now() / 1000) {
      return response.status(401).json({message: 'Your session expired. Please sign in again.'});
    }
    request.accountId = payload.sub;
    return next();
  } catch (_error) {
    return response.status(401).json({message: 'Your session is invalid. Please sign in again.'});
  }
}

async function requireAdmin(request, response, next) {
  const allowed = new Set(
    String(process.env.ADMIN_EMAILS ?? '').split(',')
      .map((email) => email.trim().toLowerCase()).filter(Boolean),
  );
  if (!allowed.size) return response.status(403).json({message: 'Administrator access is not configured.'});
  try {
    const result = await pool.query('SELECT lower(email) AS email FROM accounts WHERE id = $1', [request.accountId]);
    if (!result.rowCount || !allowed.has(result.rows[0].email)) {
      return response.status(403).json({message: 'This HowBuddy account is not an administrator.'});
    }
    return next();
  } catch (error) {
    console.error('Could not verify support administrator:', error.message);
    return response.status(500).json({message: 'Could not verify administrator access.'});
  }
}

function toAccount(row) {
  return {
    id: row.id,
    fullName: row.full_name,
    email: row.email,
    avatarPaletteIndex: row.avatar_palette_index ?? 0,
    glassesAccessoryIndex: row.glasses_accessory_index ?? 0,
    avatarEmoji: row.avatar_emoji ?? '',
    preferredLanguage: row.preferred_language ?? null,
    ageYears: row.age_years ?? null,
  };
}

async function getAccountLessonContent(request) {
  if (request.query.language) return getLessonContent(request.query.language);
  if (!request.accountId) return lessonContent;
  try {
    const result = await pool.query(
      'SELECT preferred_language FROM accounts WHERE id = $1',
      [request.accountId],
    );
    return getLessonContent(result.rows[0]?.preferred_language ?? 'en');
  } catch (error) {
    console.error('Could not load account language:', error);
    throw error;
  }
}

function findTopic(topicId, content = lessonContent) {
  const node = content.nodes[topicId];
  return node ? {
    id: node.id,
    question: node.question,
    lessonCount: Number(node.lessonCount) || 1,
  } : null;
}

function rootTopics(content = lessonContent) {
  return content.roots.map((id) => findTopic(id, content));
}

function getNextQuestions(topicId, content = lessonContent) {
  return (content.nodes[topicId]?.children ?? []).map((id) => ({
    id,
    question: content.nodes[id].question,
  }));
}

async function buildLessonLevels(topic, accountId, content = lessonContent) {
  const shapes = ['star', 'triangle', 'hexagon', 'square', 'circle'];
  const topicNode = content.nodes[topic.id];
  const count = Math.min(Number(topicNode.lessonCount) || 1, 20);
  const progress = accountId
    ? await pool.query(
        'SELECT lesson_id FROM lesson_progress WHERE account_id = $1 AND topic_id = $2',
        [accountId, topic.id],
      )
    : {rows: []};
  const lessonSet = new Set(progress.rows.map((row) => row.lesson_id));

  return Array.from({length: count}, (_item, index) => {
    const level = index + 1;
    const id = `lesson-${level}`;
    const previousId = `lesson-${level - 1}`;
    const isCompleted = lessonSet.has(id);
    const isUnlocked = level === 1 || lessonSet.has(previousId);

    return {
      id,
      level,
      shape: shapes[index % shapes.length],
      title: level === 1
        ? 'Core lesson'
        : content.nodes[topicNode.extraLessons?.[level - 2]]?.question
            ?? 'Extra lesson',
      isCompleted,
      isUnlocked,
    };
  });
}

async function buildNotepadTree(accountId, content = lessonContent) {
  const result = await pool.query(
    `SELECT topic_id, COUNT(*)::int AS count
     FROM lesson_progress WHERE account_id = $1 GROUP BY topic_id`,
    [accountId],
  );
  const completedTopics = new Set(
    result.rows
      .filter((row) => row.count >= Math.min(findTopic(row.topic_id, content)?.lessonCount ?? 20, 20))
      .map((row) => row.topic_id),
  );
  const buildNode = (id) => {
    const node = content.nodes[id];
    return {
      id,
      title: node.question,
      isCompleted: completedTopics.has(id),
      children: node.children.map(buildNode),
    };
  };
  return {
    id: 'main-tree',
    title: 'Main Tree',
    isCompleted: content.roots.every((id) => completedTopics.has(id)),
    children: content.roots.map(buildNode),
  };
}

async function ensureGameRow(accountId) {
  await pool.query(
    'INSERT INTO account_gamification (account_id) VALUES ($1) ON CONFLICT (account_id) DO NOTHING',
    [accountId],
  );
}

async function getGameState(accountId, today = new Date().toISOString().slice(0, 10)) {
  await ensureGameRow(accountId);
  await refreshHearts(accountId);
  await pool.query(
    `WITH moved AS (
       DELETE FROM study_days
       WHERE account_id = $1 AND study_date = $2::date + 1
       RETURNING account_id
     )
     INSERT INTO study_days (account_id, study_date)
     SELECT account_id, $2::date FROM moved
     ON CONFLICT DO NOTHING`,
    [accountId, today],
  );
  const [result, studyResult] = await Promise.all([
    pool.query(
      `SELECT hearts, heart_recharge_at, emeralds, xp_boost_until,
              streak_goal_days, streak_goal_started_at::text AS streak_goal_started_at
       FROM account_gamification WHERE account_id = $1`,
      [accountId],
    ),
    pool.query(
      'SELECT study_date::text AS day FROM study_days WHERE account_id = $1 ORDER BY study_date',
      [accountId],
    ),
  ]);
  const studyDays = studyResult.rows
    .map((row) => row.day)
    .filter((day) => day <= today);
  const studied = new Set(studyDays);
  let cursor = new Date(`${today}T00:00:00.000Z`);
  if (!studied.has(cursor.toISOString().slice(0, 10))) {
    cursor.setUTCDate(cursor.getUTCDate() - 1);
  }
  let streakCount = 0;
  while (studied.has(cursor.toISOString().slice(0, 10))) {
    streakCount++;
    cursor.setUTCDate(cursor.getUTCDate() - 1);
  }
  const game = result.rows[0];
  return {
    hearts: game.hearts,
    heartRechargeAt: game.heart_recharge_at?.toISOString() ?? null,
    emeralds: game.emeralds,
    streakCount,
    studyDays,
    streakGoalDays: game.streak_goal_days,
    streakGoalStartedAt: game.streak_goal_started_at,
    xpBoostUntil: game.xp_boost_until?.toISOString() ?? null,
  };
}

async function refreshHearts(accountId) {
  await pool.query(
    `UPDATE account_gamification
     SET hearts = LEAST(5, hearts + 1 + FLOOR(EXTRACT(EPOCH FROM (now() - heart_recharge_at)) / 10800)::int),
         heart_recharge_at = CASE
           WHEN hearts + 1 + FLOOR(EXTRACT(EPOCH FROM (now() - heart_recharge_at)) / 10800)::int >= 5
             THEN NULL
           ELSE heart_recharge_at +
             (1 + FLOOR(EXTRACT(EPOCH FROM (now() - heart_recharge_at)) / 10800)::int) * interval '3 hours'
         END
     WHERE account_id = $1 AND hearts < 5 AND heart_recharge_at IS NOT NULL
       AND heart_recharge_at <= now()`,
    [accountId],
  );
}

function clientStudyDate(request) {
  const candidate = request.get('X-Client-Date');
  if (!/^\d{4}-\d{2}-\d{2}$/.test(candidate ?? '')) {
    return new Date().toISOString().slice(0, 10);
  }
  const parsed = new Date(`${candidate}T00:00:00.000Z`);
  if (Number.isNaN(parsed.valueOf()) || parsed.toISOString().slice(0, 10) !== candidate) {
    return new Date().toISOString().slice(0, 10);
  }
  const utcToday = new Date().toISOString().slice(0, 10);
  const dayDelta = (parsed.valueOf() - new Date(`${utcToday}T00:00:00.000Z`).valueOf()) / 86400000;
  return Math.abs(dayDelta) <= 1 ? candidate : utcToday;
}

async function ensureNotificationSettings(accountId) {
  await pool.query(
    'INSERT INTO account_notification_settings(account_id) VALUES ($1) ON CONFLICT (account_id) DO NOTHING',
    [accountId],
  );
}

function notificationPreferencesJson(row) {
  return {
    enabled: row.enabled,
    curiosityEnabled: row.curiosity_enabled,
    quietHoursEnabled: row.quiet_hours_enabled,
    quietStartMinute: row.quiet_start_minute,
    quietEndMinute: row.quiet_end_minute,
  };
}

function clientTimezoneOffset(request) {
  const candidate = Number(request.get('X-Client-UTC-Offset-Minutes'));
  return Number.isInteger(candidate) && Math.abs(candidate) <= 840 ? candidate : 0;
}

pool.query(readFileSync(new URL('../schema.sql', import.meta.url), 'utf8')).then(async () => {
  await seedLeaderboardDemoUsers();
  await applyStudyDayBackfill();
  if (sessionSecret.length < 32) {
    throw new Error('SESSION_SECRET must contain at least 32 characters.');
  }
  app.listen(port, () => {
    console.log(`HowBuddy auth API listening on http://localhost:${port}`);
  });
  notificationScheduler.start();
}).catch((error) => {
  console.error('Could not initialize the API database schema.', error);
  process.exitCode = 1;
});

async function seedLeaderboardDemoUsers() {
  const xpAmounts = [9, 11, 21, 43, 55, 77, 89, 121, 165, 197, 233, 271, 319, 371, 424];
  for (const [index, xp] of xpAmounts.entries()) {
    const number = String(index + 1).padStart(2, '0');
    const email = `leaderboard-demo-${number}@demo.howbuddy.invalid`;
    const name = `Demo Learner ${number}`;
    const account = await pool.query(
      `INSERT INTO accounts (full_name, email, auth_provider, provider_subject)
       VALUES ($1, $2, 'demo', $3)
       ON CONFLICT (email) DO UPDATE
       SET full_name = EXCLUDED.full_name,
           auth_provider = 'demo', password_hash = NULL,
           provider_subject = EXCLUDED.provider_subject
       RETURNING id`,
      [name, email, `leaderboard-demo-${number}`],
    );
    await pool.query(
      `INSERT INTO lesson_xp (account_id, topic_id, lesson_id, xp)
       VALUES ($1, '__leaderboard_demo__', 'seeded-total', $2)
       ON CONFLICT (account_id, topic_id, lesson_id)
       DO UPDATE SET xp = EXCLUDED.xp`,
      [account.rows[0].id, xp],
    );
  }
  console.log('Leaderboard demo users are seeded.');
}

async function applyStudyDayBackfill() {
  const email = String(process.env.STUDY_HISTORY_BACKFILL_EMAIL ?? '').trim().toLowerCase();
  const endDate = String(process.env.STUDY_HISTORY_BACKFILL_END_DATE ?? '').trim();
  if (!email && !endDate) return;
  if (!email || !/^\d{4}-\d{2}-\d{2}$/.test(endDate)) {
    throw new Error('Study history backfill needs an account email and a YYYY-MM-DD end date.');
  }
  const parsedDate = new Date(`${endDate}T00:00:00.000Z`);
  if (Number.isNaN(parsedDate.valueOf()) || parsedDate.toISOString().slice(0, 10) !== endDate) {
    throw new Error('Study history backfill end date is not a valid calendar date.');
  }
  const result = await pool.query(
    `INSERT INTO study_days (account_id, study_date)
     SELECT accounts.id, $2::date - dates.day_offset
     FROM accounts
     CROSS JOIN generate_series(1, 4) AS dates(day_offset)
     WHERE lower(accounts.email) = $1
     ON CONFLICT DO NOTHING`,
    [email, endDate],
  );
  const xpResult = await pool.query(
    `WITH target_account AS (
       SELECT id FROM accounts WHERE lower(email) = $1
     ), backfill_days AS (
       SELECT target_account.id AS account_id,
              ($2::date - days.day_offset)::date AS xp_date
       FROM target_account
       CROSS JOIN generate_series(1, 4) AS days(day_offset)
     )
     INSERT INTO lesson_xp (account_id, topic_id, lesson_id, xp, created_at)
     SELECT account_id,
            '__history_backfill__',
            'day-' || xp_date::text,
            floor(random() * 95)::int + 9,
            (xp_date + time '12:00') AT TIME ZONE 'UTC'
     FROM backfill_days
     ON CONFLICT DO NOTHING
     RETURNING xp, (created_at AT TIME ZONE 'UTC')::date::text AS date`,
    [email, endDate],
  );
  console.log(`Historical study-day backfill inserted ${result.rowCount} rows.`);
  console.log(
    `Historical XP backfill inserted ${xpResult.rowCount} rows: ${xpResult.rows
      .map((row) => `${row.date}=${row.xp}`)
      .join(', ')}`,
  );
}
