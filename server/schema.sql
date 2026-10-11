CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  username TEXT UNIQUE,
  password_hash TEXT,
  auth_provider TEXT NOT NULL DEFAULT 'password',
  provider_subject TEXT UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

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
  emeralds INTEGER NOT NULL DEFAULT 100 CHECK (emeralds >= 0),
  xp_boost_until TIMESTAMPTZ
);
