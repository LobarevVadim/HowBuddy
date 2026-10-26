CREATE TABLE IF NOT EXISTS lesson_content_by_language (
  language_code TEXT PRIMARY KEY CHECK (language_code IN ('en', 'fr', 'hi', 'es', 'ru')),
  content JSONB NOT NULL CHECK (jsonb_typeof(content) = 'object'),
  source_sha256 CHAR(64) NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Normalized, editable content. The legacy snapshots remain as a rollback source.
CREATE TABLE IF NOT EXISTS content_topics (
  topic_id TEXT PRIMARY KEY,
  parent_topic_id TEXT REFERENCES content_topics(topic_id) ON DELETE RESTRICT,
  tree_position INTEGER NOT NULL CHECK (tree_position >= 0),
  level INTEGER NOT NULL CHECK (level >= 1),
  lesson_count INTEGER NOT NULL DEFAULT 1 CHECK (lesson_count >= 1),
  visible_in_tree BOOLEAN NOT NULL DEFAULT true,
  status TEXT NOT NULL DEFAULT 'published' CHECK (status IN ('draft', 'published')),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS content_topics_parent_order_idx
  ON content_topics(parent_topic_id, tree_position);

-- Tree metadata is language-specific because existing language snapshots do
-- not all have identical lesson counts or extra-lesson mappings.
CREATE TABLE IF NOT EXISTS content_topic_translations (
  topic_id TEXT NOT NULL REFERENCES content_topics(topic_id) ON DELETE CASCADE,
  language_code TEXT NOT NULL CHECK (language_code IN ('en', 'fr', 'hi', 'es', 'ru')),
  question TEXT NOT NULL,
  tree_data JSONB NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(tree_data) = 'object'),
  status TEXT NOT NULL DEFAULT 'published' CHECK (status IN ('draft', 'published')),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (topic_id, language_code)
);

CREATE TABLE IF NOT EXISTS content_tree_roots (
  language_code TEXT NOT NULL CHECK (language_code IN ('en', 'fr', 'hi', 'es', 'ru')),
  tree_position INTEGER NOT NULL CHECK (tree_position >= 0),
  topic_id TEXT NOT NULL REFERENCES content_topics(topic_id) ON DELETE RESTRICT,
  PRIMARY KEY (language_code, tree_position),
  UNIQUE (language_code, topic_id)
);

CREATE TABLE IF NOT EXISTS content_lessons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  topic_id TEXT NOT NULL REFERENCES content_topics(topic_id) ON DELETE CASCADE,
  lesson_number INTEGER NOT NULL CHECK (lesson_number >= 1),
  UNIQUE (topic_id, lesson_number)
);

CREATE TABLE IF NOT EXISTS content_lesson_translations (
  lesson_id UUID NOT NULL REFERENCES content_lessons(id) ON DELETE CASCADE,
  language_code TEXT NOT NULL CHECK (language_code IN ('en', 'fr', 'es', 'hi', 'ru')),
  material_topic_id TEXT NOT NULL REFERENCES content_topics(topic_id) ON DELETE RESTRICT,
  title TEXT NOT NULL,
  content TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'published' CHECK (status IN ('draft', 'published')),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (lesson_id, language_code)
);

CREATE TABLE IF NOT EXISTS content_lesson_drafts (
  lesson_id UUID NOT NULL REFERENCES content_lessons(id) ON DELETE CASCADE,
  language_code TEXT NOT NULL CHECK (language_code IN ('en', 'fr', 'es', 'hi', 'ru')),
  material_topic_id TEXT REFERENCES content_topics(topic_id) ON DELETE RESTRICT,
  material_topic_id TEXT REFERENCES content_topics(topic_id) ON DELETE RESTRICT,
  title TEXT NOT NULL,
  content TEXT NOT NULL DEFAULT '',
  updated_by UUID REFERENCES accounts(id) ON DELETE SET NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (lesson_id, language_code)
);

-- Every localized exercise is an independent typed JSONB row. This preserves
-- legacy cases where exercise types/counts differ across languages.
CREATE TABLE IF NOT EXISTS content_exercises (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id UUID NOT NULL REFERENCES content_lessons(id) ON DELETE CASCADE,
  language_code TEXT NOT NULL CHECK (language_code IN ('en', 'fr', 'es', 'hi', 'ru')),
  position INTEGER NOT NULL CHECK (position >= 0),
  exercise_type TEXT NOT NULL CHECK (exercise_type IN (
    'singleChoice', 'multipleSelect', 'shortAnswer', 'orderSteps', 'matching',
    'fillInTheBlank', 'trueFalse', 'spotTheMistake', 'categorization',
    'causeAndEffect', 'compareAndContrast', 'buildTheProcess'
  )),
  exercise_json JSONB NOT NULL CHECK (jsonb_typeof(exercise_json) = 'object' AND exercise_json->>'type' = exercise_type),
  status TEXT NOT NULL DEFAULT 'published' CHECK (status IN ('draft', 'published')),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (lesson_id, language_code, position)
);
CREATE INDEX IF NOT EXISTS content_exercises_lesson_order_idx
  ON content_exercises(lesson_id, language_code, position);

CREATE TABLE IF NOT EXISTS content_exercise_drafts (
  exercise_id UUID NOT NULL REFERENCES content_exercises(id) ON DELETE CASCADE,
  language_code TEXT NOT NULL CHECK (language_code IN ('en', 'fr', 'es', 'hi', 'ru')),
  exercise_json JSONB NOT NULL CHECK (jsonb_typeof(exercise_json) = 'object'),
  updated_by UUID REFERENCES accounts(id) ON DELETE SET NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (exercise_id, language_code)
);

CREATE TABLE IF NOT EXISTS content_revisions (
  id BIGSERIAL PRIMARY KEY,
  entity_type TEXT NOT NULL CHECK (entity_type IN ('topic', 'lesson', 'exercise')),
  entity_id TEXT NOT NULL,
  language_code TEXT CHECK (language_code IS NULL OR language_code IN ('en', 'fr', 'es', 'hi', 'ru')),
  revision_number INTEGER NOT NULL CHECK (revision_number >= 1),
  status TEXT NOT NULL CHECK (status IN ('draft', 'published')),
  snapshot JSONB NOT NULL CHECK (jsonb_typeof(snapshot) = 'object'),
  changed_by UUID REFERENCES accounts(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (entity_type, entity_id, language_code, revision_number)
);
CREATE INDEX IF NOT EXISTS content_revisions_entity_idx
  ON content_revisions(entity_type, entity_id, language_code, revision_number DESC);
