-- Additive expansion. Existing progress/XP is intentionally not rewritten.
ALTER TABLE bobo_exercise_tutoring_state ADD COLUMN IF NOT EXISTS content_revision TEXT;
CREATE TABLE IF NOT EXISTS lesson_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  topic_id TEXT NOT NULL,
  lesson_id TEXT NOT NULL,
  start_key TEXT NOT NULL,
  content_revision TEXT NOT NULL,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(account_id, start_key)
);
CREATE INDEX IF NOT EXISTS lesson_sessions_account_idx ON lesson_sessions(account_id);
ALTER TABLE bobo_exercise_tutoring_state ADD COLUMN IF NOT EXISTS session_id UUID REFERENCES lesson_sessions(id) ON DELETE SET NULL;
CREATE TABLE IF NOT EXISTS lesson_session_attempts (
  session_id UUID NOT NULL REFERENCES lesson_sessions(id) ON DELETE CASCADE,
  exercise_index INTEGER NOT NULL CHECK(exercise_index >= 0),
  student_answer TEXT NOT NULL,
  answer_json JSONB,
  content_revision TEXT NOT NULL,
  PRIMARY KEY(session_id, exercise_index)
);
CREATE TABLE IF NOT EXISTS lesson_completion_receipts (
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  topic_id TEXT NOT NULL,
  lesson_id TEXT NOT NULL,
  completion_id TEXT NOT NULL,
  result JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (account_id, topic_id, lesson_id, completion_id)
);
