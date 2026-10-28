CREATE TABLE IF NOT EXISTS content_generation (
  singleton BOOLEAN PRIMARY KEY DEFAULT true CHECK (singleton),
  generation BIGINT NOT NULL DEFAULT 1
);
INSERT INTO content_generation(singleton) VALUES(true) ON CONFLICT DO NOTHING;
CREATE OR REPLACE FUNCTION bump_content_generation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  UPDATE content_generation SET generation=generation+1 WHERE singleton;
  RETURN NULL;
END $$;
DO $$
DECLARE table_name TEXT;
BEGIN
  FOREACH table_name IN ARRAY ARRAY['content_topics','content_topic_translations','content_tree_roots',
    'content_lessons','content_lesson_translations','content_exercises'] LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='content_generation_changed' AND tgrelid=table_name::regclass) THEN
      EXECUTE format('CREATE TRIGGER content_generation_changed AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON %I FOR EACH STATEMENT EXECUTE FUNCTION bump_content_generation()', table_name);
    END IF;
  END LOOP;
END $$;
