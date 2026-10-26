CREATE TABLE IF NOT EXISTS lesson_content_by_language (
  language_code TEXT PRIMARY KEY CHECK (language_code IN ('en', 'fr', 'hi', 'es', 'ru')),
  content JSONB NOT NULL CHECK (jsonb_typeof(content) = 'object'),
  source_sha256 CHAR(64) NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
