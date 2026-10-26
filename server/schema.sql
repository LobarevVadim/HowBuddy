CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  username TEXT UNIQUE,
  password_hash TEXT,
  auth_provider TEXT NOT NULL DEFAULT 'password',
  provider_subject TEXT UNIQUE,
  preferred_language TEXT,
  age_years SMALLINT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS account_legal_acceptances (
  account_id UUID PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
  terms_version TEXT NOT NULL,
  privacy_version TEXT NOT NULL,
  cookie_policy_version TEXT NOT NULL,
  refund_policy_version TEXT NOT NULL,
  accepted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE accounts ADD COLUMN IF NOT EXISTS preferred_language TEXT;
ALTER TABLE accounts ADD COLUMN IF NOT EXISTS age_years SMALLINT;

DO $$
BEGIN
  ALTER TABLE accounts ADD CONSTRAINT accounts_preferred_language_check
    CHECK (preferred_language IS NULL OR preferred_language IN ('en', 'fr', 'es', 'hi', 'ru'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE accounts ADD CONSTRAINT accounts_age_years_check
    CHECK (age_years IS NULL OR age_years BETWEEN 1 AND 120);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE accounts ADD COLUMN IF NOT EXISTS last_topic_id TEXT;
ALTER TABLE accounts ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMPTZ;
ALTER TABLE accounts
  ADD COLUMN IF NOT EXISTS avatar_palette_index INTEGER NOT NULL DEFAULT 0
  CHECK (avatar_palette_index BETWEEN 0 AND 20);
ALTER TABLE accounts
  ADD COLUMN IF NOT EXISTS glasses_accessory_index INTEGER NOT NULL DEFAULT 0
  CHECK (glasses_accessory_index BETWEEN 0 AND 16);
ALTER TABLE accounts
  ADD COLUMN IF NOT EXISTS avatar_emoji TEXT NOT NULL DEFAULT '';

CREATE TABLE IF NOT EXISTS account_notification_settings (
  account_id UUID PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
  enabled BOOLEAN NOT NULL DEFAULT false,
  curiosity_enabled BOOLEAN NOT NULL DEFAULT true,
  quiet_hours_enabled BOOLEAN NOT NULL DEFAULT true,
  quiet_start_minute SMALLINT NOT NULL DEFAULT 1320 CHECK (quiet_start_minute BETWEEN 0 AND 1439),
  quiet_end_minute SMALLINT NOT NULL DEFAULT 480 CHECK (quiet_end_minute BETWEEN 0 AND 1439),
  time_zone TEXT NOT NULL DEFAULT 'UTC',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS notification_devices (
  token TEXT PRIMARY KEY,
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios', 'web')),
  language TEXT NOT NULL DEFAULT 'en' CHECK (language IN ('en', 'fr', 'es', 'hi', 'ru')),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS notification_devices_account_idx ON notification_devices(account_id);

CREATE TABLE IF NOT EXISTS notification_deliveries (
  id BIGSERIAL PRIMARY KEY,
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  local_date DATE NOT NULL,
  notification_type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL DEFAULT '',
  topic_id TEXT NOT NULL DEFAULT '',
  sent_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (account_id, local_date, notification_type)
);
CREATE INDEX IF NOT EXISTS notification_deliveries_day_idx ON notification_deliveries(account_id, local_date);

CREATE TABLE IF NOT EXISTS lesson_xp (
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  topic_id TEXT NOT NULL,
  lesson_id TEXT NOT NULL,
  xp INTEGER NOT NULL CHECK (xp BETWEEN 1 AND 1000),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (account_id, topic_id, lesson_id)
);

CREATE TABLE IF NOT EXISTS lesson_progress (
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  topic_id TEXT NOT NULL,
  lesson_id TEXT NOT NULL,
  completed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (account_id, topic_id, lesson_id)
);

CREATE TABLE IF NOT EXISTS bobo_daily_usage (
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  usage_date DATE NOT NULL,
  request_count INTEGER NOT NULL DEFAULT 0 CHECK (request_count >= 0),
  estimated_tokens INTEGER NOT NULL DEFAULT 0 CHECK (estimated_tokens >= 0),
  input_tokens INTEGER NOT NULL DEFAULT 0 CHECK (input_tokens >= 0),
  output_tokens INTEGER NOT NULL DEFAULT 0 CHECK (output_tokens >= 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (account_id, usage_date)
);

CREATE TABLE IF NOT EXISTS bobo_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  topic_id TEXT NOT NULL,
  lesson_id TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (account_id, topic_id, lesson_id)
);
CREATE INDEX IF NOT EXISTS bobo_conversations_account_updated_idx
  ON bobo_conversations(account_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS bobo_messages (
  id BIGSERIAL PRIMARY KEY,
  conversation_id UUID NOT NULL REFERENCES bobo_conversations(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
  content TEXT NOT NULL CHECK (char_length(content) BETWEEN 1 AND 5000),
  exercise_index INTEGER CHECK (exercise_index IS NULL OR exercise_index >= 0),
  input_tokens INTEGER NOT NULL DEFAULT 0 CHECK (input_tokens >= 0),
  output_tokens INTEGER NOT NULL DEFAULT 0 CHECK (output_tokens >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS bobo_messages_conversation_created_idx
  ON bobo_messages(conversation_id, created_at DESC, id DESC);

CREATE TABLE IF NOT EXISTS bobo_exercise_tutoring_state (
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  topic_id TEXT NOT NULL,
  lesson_id TEXT NOT NULL,
  exercise_index INTEGER NOT NULL CHECK (exercise_index >= 0),
  student_answer TEXT CHECK (student_answer IS NULL OR char_length(student_answer) <= 2000),
  answer_correct BOOLEAN,
  attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  attempted_at TIMESTAMPTZ,
  hint_level INTEGER NOT NULL DEFAULT 0 CHECK (hint_level BETWEEN 0 AND 4),
  tutoring_mode TEXT NOT NULL DEFAULT 'socratic',
  tutoring_state TEXT NOT NULL DEFAULT 'diagnosing',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (account_id, topic_id, lesson_id, exercise_index)
);

ALTER TABLE lesson_xp DROP CONSTRAINT IF EXISTS lesson_xp_xp_check;
ALTER TABLE lesson_xp ADD CONSTRAINT lesson_xp_xp_check CHECK (xp BETWEEN 1 AND 1000);

CREATE TABLE IF NOT EXISTS study_days (
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  study_date DATE NOT NULL,
  PRIMARY KEY (account_id, study_date)
);

CREATE TABLE IF NOT EXISTS streak_freeze_calendar_days (
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  frozen_date DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (account_id, frozen_date)
);
CREATE INDEX IF NOT EXISTS streak_freeze_calendar_days_date_idx
  ON streak_freeze_calendar_days(account_id, frozen_date);

CREATE TABLE IF NOT EXISTS streak_freeze_alerts (
  account_id UUID NOT NULL,
  frozen_date DATE NOT NULL,
  notify_on DATE NOT NULL,
  claimed_at TIMESTAMPTZ,
  PRIMARY KEY (account_id, frozen_date),
  FOREIGN KEY (account_id, frozen_date)
    REFERENCES streak_freeze_calendar_days(account_id, frozen_date) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS streak_freeze_alerts_pending_idx
  ON streak_freeze_alerts(notify_on) WHERE claimed_at IS NULL;

-- Preserve existing activity using the records already collected by HowBuddy.
WITH activity AS (
  SELECT account_id, MAX(active_at) AS last_active_at
  FROM (
    SELECT account_id, completed_at AS active_at FROM lesson_progress
    UNION ALL
    SELECT account_id, last_seen_at AS active_at FROM notification_devices
    UNION ALL
    SELECT account_id, study_date::timestamp AT TIME ZONE 'UTC' AS active_at
    FROM study_days WHERE study_date <= CURRENT_DATE
  ) AS existing_activity
  GROUP BY account_id
)
UPDATE accounts AS account
SET last_active_at = COALESCE(activity.last_active_at, account.created_at)
FROM activity
WHERE account.id = activity.account_id AND account.last_active_at IS NULL;

UPDATE accounts
SET last_active_at = created_at
WHERE last_active_at IS NULL;

DROP TABLE IF EXISTS lesson_starts;

DROP TABLE IF EXISTS topic_selections;

CREATE TABLE IF NOT EXISTS account_gamification (
  account_id UUID PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
  hearts INTEGER NOT NULL DEFAULT 5 CHECK (hearts BETWEEN 0 AND 5),
  heart_recharge_at TIMESTAMPTZ,
  emeralds INTEGER NOT NULL DEFAULT 100 CHECK (emeralds >= 0),
  xp_boost_until TIMESTAMPTZ,
  streak_freezes_remaining INTEGER NOT NULL DEFAULT 0 CHECK (streak_freezes_remaining >= 0),
  streak_goal_days SMALLINT CHECK (streak_goal_days IN (7, 14, 30)),
  streak_goal_started_at DATE
);

ALTER TABLE account_gamification
  ADD COLUMN IF NOT EXISTS heart_recharge_at TIMESTAMPTZ;
ALTER TABLE account_gamification
  ADD COLUMN IF NOT EXISTS streak_goal_days SMALLINT;
ALTER TABLE account_gamification
  ADD COLUMN IF NOT EXISTS streak_goal_started_at DATE;
ALTER TABLE account_gamification
  ADD COLUMN IF NOT EXISTS streak_freezes_remaining INTEGER NOT NULL DEFAULT 0;
UPDATE account_gamification
SET streak_freezes_remaining = 0
WHERE streak_freezes_remaining IS NULL;
ALTER TABLE account_gamification
  ALTER COLUMN streak_freezes_remaining SET DEFAULT 0;
ALTER TABLE account_gamification
  ALTER COLUMN streak_freezes_remaining SET NOT NULL;

DO $$
BEGIN
  ALTER TABLE account_gamification ADD CONSTRAINT account_gamification_streak_goal_days_check
    CHECK (streak_goal_days IS NULL OR streak_goal_days IN (7, 14, 30));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE account_gamification ADD CONSTRAINT account_gamification_streak_freezes_remaining_check
    CHECK (streak_freezes_remaining >= 0);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

UPDATE account_gamification
SET heart_recharge_at = now() + interval '3 hours'
WHERE hearts < 5 AND heart_recharge_at IS NULL;

CREATE TABLE IF NOT EXISTS support_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  inbox_address TEXT NOT NULL CHECK (inbox_address IN ('hello@howbuddy.app', 'support@howbuddy.app', 'contact@howbuddy.app')),
  sender_email TEXT NOT NULL,
  subject TEXT NOT NULL DEFAULT '',
  is_read BOOLEAN NOT NULL DEFAULT false,
  last_activity_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS support_conversations_activity_idx ON support_conversations(last_activity_at DESC);
CREATE TABLE IF NOT EXISTS support_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES support_conversations(id) ON DELETE CASCADE,
  direction TEXT NOT NULL CHECK (direction IN ('inbound', 'outbound')),
  sender_email TEXT NOT NULL,
  sender_name TEXT NOT NULL DEFAULT '',
  recipient_email TEXT NOT NULL,
  cc_emails TEXT[] NOT NULL DEFAULT '{}',
  bcc_emails TEXT[] NOT NULL DEFAULT '{}',
  reply_to_emails TEXT[] NOT NULL DEFAULT '{}',
  received_for TEXT[] NOT NULL DEFAULT '{}',
  email_headers JSONB NOT NULL DEFAULT '{}'::jsonb,
  subject TEXT NOT NULL DEFAULT '',
  text_body TEXT NOT NULL DEFAULT '',
  html_body TEXT NOT NULL DEFAULT '',
  sent_attachments JSONB NOT NULL DEFAULT '[]'::jsonb,
  provider_email_id TEXT UNIQUE,
  message_id TEXT,
  in_reply_to TEXT,
  references_header TEXT[] NOT NULL DEFAULT '{}',
  forwarded_at TIMESTAMPTZ,
  received_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE support_messages ADD COLUMN IF NOT EXISTS sender_name TEXT NOT NULL DEFAULT '';
ALTER TABLE support_messages ADD COLUMN IF NOT EXISTS cc_emails TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE support_messages ADD COLUMN IF NOT EXISTS bcc_emails TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE support_messages ADD COLUMN IF NOT EXISTS reply_to_emails TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE support_messages ADD COLUMN IF NOT EXISTS received_for TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE support_messages ADD COLUMN IF NOT EXISTS email_headers JSONB NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE support_messages ADD COLUMN IF NOT EXISTS forwarded_at TIMESTAMPTZ;
ALTER TABLE support_messages ADD COLUMN IF NOT EXISTS sent_attachments JSONB NOT NULL DEFAULT '[]'::jsonb;
CREATE INDEX IF NOT EXISTS support_messages_conversation_idx ON support_messages(conversation_id, received_at);
CREATE INDEX IF NOT EXISTS support_messages_message_id_idx ON support_messages(message_id);
CREATE TABLE IF NOT EXISTS support_attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES support_messages(id) ON DELETE CASCADE,
  provider_attachment_id TEXT NOT NULL,
  filename TEXT NOT NULL,
  content_type TEXT NOT NULL DEFAULT 'application/octet-stream',
  size_bytes BIGINT NOT NULL DEFAULT 0,
  content_disposition TEXT NOT NULL DEFAULT 'attachment',
  content_id TEXT NOT NULL DEFAULT '',
  UNIQUE (message_id, provider_attachment_id)
);
ALTER TABLE support_attachments ADD COLUMN IF NOT EXISTS content_disposition TEXT NOT NULL DEFAULT 'attachment';
ALTER TABLE support_attachments ADD COLUMN IF NOT EXISTS content_id TEXT NOT NULL DEFAULT '';
