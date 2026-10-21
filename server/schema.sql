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

ALTER TABLE lesson_xp DROP CONSTRAINT IF EXISTS lesson_xp_xp_check;
ALTER TABLE lesson_xp ADD CONSTRAINT lesson_xp_xp_check CHECK (xp BETWEEN 1 AND 1000);

CREATE TABLE IF NOT EXISTS study_days (
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  study_date DATE NOT NULL,
  PRIMARY KEY (account_id, study_date)
);

CREATE TABLE IF NOT EXISTS account_gamification (
  account_id UUID PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
  hearts INTEGER NOT NULL DEFAULT 5 CHECK (hearts BETWEEN 0 AND 5),
  heart_recharge_at TIMESTAMPTZ,
  emeralds INTEGER NOT NULL DEFAULT 100 CHECK (emeralds >= 0),
  xp_boost_until TIMESTAMPTZ
);

ALTER TABLE account_gamification
  ADD COLUMN IF NOT EXISTS heart_recharge_at TIMESTAMPTZ;

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
  recipient_email TEXT NOT NULL,
  subject TEXT NOT NULL DEFAULT '',
  text_body TEXT NOT NULL DEFAULT '',
  html_body TEXT NOT NULL DEFAULT '',
  provider_email_id TEXT UNIQUE,
  message_id TEXT,
  in_reply_to TEXT,
  references_header TEXT[] NOT NULL DEFAULT '{}',
  received_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS support_messages_conversation_idx ON support_messages(conversation_id, received_at);
CREATE INDEX IF NOT EXISTS support_messages_message_id_idx ON support_messages(message_id);
CREATE TABLE IF NOT EXISTS support_attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES support_messages(id) ON DELETE CASCADE,
  provider_attachment_id TEXT NOT NULL,
  filename TEXT NOT NULL,
  content_type TEXT NOT NULL DEFAULT 'application/octet-stream',
  size_bytes BIGINT NOT NULL DEFAULT 0,
  UNIQUE (message_id, provider_attachment_id)
);
