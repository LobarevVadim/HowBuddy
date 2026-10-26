import {randomUUID} from 'node:crypto';
import {EXERCISE_TYPES, validateExercisePayload} from './normalized_lesson_content.js';

const LANGUAGES = ['en', 'fr', 'es', 'hi', 'ru'];
const parseJson = (value) => typeof value === 'string' ? JSON.parse(value) : value;

export async function getContentAdminState(pool) {
  const [legacy, normalized] = await Promise.all([
    pool.query('SELECT language_code FROM lesson_content_by_language ORDER BY language_code'),
    pool.query(`SELECT
      (SELECT COUNT(*)::int FROM content_topics) AS topics,
      (SELECT COUNT(*)::int FROM content_lessons) AS lessons,
      (SELECT COUNT(*)::int FROM content_exercises) AS exercises,
      (SELECT COUNT(DISTINCT language_code)::int FROM content_exercises) AS exercise_languages`),
  ]);
  const row = normalized.rows[0];
  return {
    migrated: Number(row.topics) > 0,
    languages: legacy.rows.map((item) => item.language_code),
    topics: Number(row.topics),
    lessons: Number(row.lessons),
    exercises: Number(row.exercises),
    exerciseTranslations: Number(row.exercises),
    exerciseLanguages: Number(row.exercise_languages),
  };
}

export async function listContentTopics(pool, language = 'en') {
  const lang = LANGUAGES.includes(language) ? language : 'en';
  const result = await pool.query(
    `SELECT t.topic_id, tr.tree_data, tr.question
     FROM content_topics t
     JOIN content_topic_translations tr
       ON tr.topic_id = t.topic_id AND tr.language_code = $1 AND tr.status = 'published'
     WHERE t.visible_in_tree = true AND t.status = 'published'
     ORDER BY t.level, t.tree_position, t.topic_id`, [lang]);
  return result.rows.map((row) => {
    const tree = parseJson(row.tree_data) ?? {};
    return {
      id: row.topic_id,
      parentId: tree.parentId ?? null,
      level: Number(tree.level) || 1,
      lessonCount: Number(tree.lessonCount) || 1,
      question: row.question,
    };
  });
}

export async function listContentLessons(pool, topicId, language = 'en') {
  const lang = LANGUAGES.includes(language) ? language : 'en';
  const result = await pool.query(
    `SELECT l.id, l.topic_id, l.lesson_number,
            COALESCE(d.material_topic_id, own.material_topic_id, english.material_topic_id) AS material_topic_id,
            COALESCE(d.title, own.title, english.title, '') AS title,
            COALESCE(d.content, own.content, english.content, '') AS content,
            CASE WHEN d.lesson_id IS NOT NULL THEN 'draft'
                 ELSE COALESCE(own.status, english.status, 'draft') END AS status,
            (SELECT COUNT(*)::int FROM content_exercises e
             WHERE e.lesson_id = l.id AND e.language_code =
               COALESCE(own.language_code, english.language_code, $2)) AS exercise_count
     FROM content_lessons l
     LEFT JOIN content_lesson_drafts d ON d.lesson_id = l.id AND d.language_code = $2
     LEFT JOIN content_lesson_translations own
       ON own.lesson_id = l.id AND own.language_code = $2 AND own.status = 'published'
     LEFT JOIN content_lesson_translations english
       ON english.lesson_id = l.id AND english.language_code = 'en' AND english.status = 'published'
     WHERE l.topic_id = $1 AND (d.lesson_id IS NOT NULL OR own.lesson_id IS NOT NULL OR english.lesson_id IS NOT NULL)
     ORDER BY l.lesson_number`, [topicId, lang]);
  return result.rows.map((row) => ({
    id: row.id,
    topicId: row.topic_id,
    lessonNumber: Number(row.lesson_number),
    materialTopicId: row.material_topic_id,
    title: row.title,
    content: row.content,
    status: row.status,
    exerciseCount: Number(row.exercise_count),
  }));
}

export async function getContentLesson(pool, lessonId, language = 'en') {
  const lang = LANGUAGES.includes(language) ? language : 'en';
  const lessonResult = await pool.query(
    `SELECT l.id, l.topic_id, l.lesson_number,
            COALESCE(d.material_topic_id, own.material_topic_id, english.material_topic_id) AS material_topic_id,
            COALESCE(d.title, own.title, english.title, '') AS title,
            COALESCE(d.content, own.content, english.content, '') AS content,
            CASE WHEN d.lesson_id IS NOT NULL THEN $2
                 ELSE COALESCE(own.language_code, english.language_code, $2) END AS content_language,
            CASE WHEN d.lesson_id IS NOT NULL THEN 'draft'
                 ELSE COALESCE(own.status, english.status, 'draft') END AS status,
            d.lesson_id IS NOT NULL AS has_draft
     FROM content_lessons l
     LEFT JOIN content_lesson_drafts d ON d.lesson_id = l.id AND d.language_code = $2
     LEFT JOIN content_lesson_translations own
       ON own.lesson_id = l.id AND own.language_code = $2 AND own.status = 'published'
     LEFT JOIN content_lesson_translations english
       ON english.lesson_id = l.id AND english.language_code = 'en' AND english.status = 'published'
     WHERE l.id = $1`, [lessonId, lang]);
  if (!lessonResult.rowCount) return null;
  const lesson = lessonResult.rows[0];
  const exercises = await loadAdminExercises(pool, lessonId, lang);
  if (lang !== 'en') {
    const english = await loadAdminExercises(pool, lessonId, 'en');
    const positions = new Set(exercises.map((item) => item.position));
    for (const item of english) {
      if (!positions.has(item.position)) exercises.push({...item, isFallback: true});
    }
  }
  return {
    id: lesson.id,
    topicId: lesson.topic_id,
    lessonNumber: Number(lesson.lesson_number),
    materialTopicId: lesson.material_topic_id,
    title: lesson.title,
    content: lesson.content,
    status: lesson.status,
    hasDraft: lesson.has_draft,
    exercises,
  };
}

async function loadAdminExercises(pool, lessonId, language) {
  const result = await pool.query(
    `SELECT e.id, e.position, e.exercise_type, e.status,
            COALESCE(d.exercise_json, e.exercise_json) AS exercise_json,
            d.exercise_json IS NOT NULL AS has_draft
     FROM content_exercises e
     LEFT JOIN content_exercise_drafts d ON d.exercise_id = e.id AND d.language_code = e.language_code
     WHERE e.lesson_id = $1 AND e.language_code = $2
     ORDER BY e.position`, [lessonId, language]);
  return result.rows.map((row) => ({
    id: row.id,
    position: Number(row.position),
    type: row.exercise_type,
    language,
    isFallback: false,
    status: row.status,
    hasDraft: row.has_draft,
    payload: parseJson(row.exercise_json),
  }));
}

export async function saveLessonDraft(pool, {lessonId, language, title, content, accountId}) {
  if (!LANGUAGES.includes(language)) throw new Error('Select a supported language.');
  if (!String(title ?? '').trim()) throw new Error('Lesson title is required.');
  if (typeof content !== 'string') throw new Error('Lesson content must be text.');
  const material = await pool.query(
    `SELECT material_topic_id FROM content_lesson_translations
     WHERE lesson_id = $1 AND language_code = ANY($2::text[])
     ORDER BY (language_code = $3) DESC LIMIT 1`,
    [lessonId, language === 'en' ? ['en'] : [language, 'en'], language]);
  await pool.query(
    `INSERT INTO content_lesson_drafts(lesson_id, language_code, material_topic_id, title, content, updated_by)
     VALUES ($1, $2, $3, $4, $5, $6)
     ON CONFLICT (lesson_id, language_code) DO UPDATE SET
       title = EXCLUDED.title, content = EXCLUDED.content,
       updated_by = EXCLUDED.updated_by, updated_at = now()`,
    [lessonId, language, material.rows[0]?.material_topic_id ?? null, title.trim(), content, accountId]);
  return {saved: true, status: 'draft'};
}

export async function publishLesson(pool, {lessonId, language, accountId}) {
  if (!LANGUAGES.includes(language)) throw new Error('Select a supported language.');
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const lesson = await client.query('SELECT * FROM content_lessons WHERE id = $1 FOR UPDATE', [lessonId]);
    if (!lesson.rowCount) throw new Error('Lesson not found.');
    const draft = await client.query(
      'SELECT material_topic_id, title, content FROM content_lesson_drafts WHERE lesson_id = $1 AND language_code = $2 FOR UPDATE',
      [lessonId, language]);
    if (!draft.rowCount) throw new Error('Save a lesson draft before publishing.');
    const hasPublishedExercise = await client.query(
      `SELECT EXISTS (SELECT 1 FROM content_exercises
       WHERE lesson_id = $1 AND language_code = $2 AND status = 'published') AS ready`,
      [lessonId, language]);
    if (!hasPublishedExercise.rows[0].ready) {
      throw new Error(`Publish at least one ${language.toUpperCase()} exercise before publishing this lesson.`);
    }
    const current = await client.query(
      `SELECT material_topic_id, title, content FROM content_lesson_translations
       WHERE lesson_id = $1 AND language_code = $2`, [lessonId, language]);
    const revision = await client.query(
      `SELECT COALESCE(MAX(revision_number), 0)::int AS revision
       FROM content_revisions WHERE entity_type = 'lesson' AND entity_id = $1 AND language_code = $2`,
      [lessonId, language]);
    const snapshot = current.rowCount ? current.rows[0] : draft.rows[0];
    await client.query(
      `INSERT INTO content_revisions(entity_type, entity_id, language_code, revision_number,
        status, snapshot, changed_by) VALUES ('lesson', $1, $2, $3, 'published', $4::jsonb, $5)`,
      [lessonId, language, Number(revision.rows[0].revision) + 1, JSON.stringify(snapshot), accountId]);
    const materialTopicId = draft.rows[0].material_topic_id ?? current.rows[0]?.material_topic_id;
    if (!materialTopicId) throw new Error('The lesson does not have source content attached.');
    await client.query(
      `INSERT INTO content_lesson_translations
        (lesson_id, language_code, material_topic_id, title, content, status)
       VALUES ($1, $2, $3, $4, $5, 'published')
       ON CONFLICT (lesson_id, language_code) DO UPDATE SET
         material_topic_id = EXCLUDED.material_topic_id, title = EXCLUDED.title,
         content = EXCLUDED.content, status = 'published', updated_at = now()`,
      [lessonId, language, materialTopicId, draft.rows[0].title, draft.rows[0].content]);
    if (Number(lesson.rows[0].lesson_number) > 1) {
      const treeResult = await client.query(
        `SELECT tree_data FROM content_topic_translations
         WHERE topic_id = $1 AND language_code = $2 AND status = 'published' FOR UPDATE`,
        [lesson.rows[0].topic_id, language]);
      if (!treeResult.rowCount) throw new Error('Publish the topic translation before publishing its lesson.');
      const treeData = parseJson(treeResult.rows[0].tree_data) ?? {};
      const extraLessons = Array.isArray(treeData.extraLessons) ? [...treeData.extraLessons] : [];
      extraLessons[Number(lesson.rows[0].lesson_number) - 2] = materialTopicId;
      treeData.extraLessons = extraLessons;
      treeData.lessonCount = Math.max(Number(treeData.lessonCount) || 1, Number(lesson.rows[0].lesson_number));
      await client.query(
        `UPDATE content_topic_translations SET tree_data = $3::jsonb, updated_at = now()
         WHERE topic_id = $1 AND language_code = $2`,
        [lesson.rows[0].topic_id, language, JSON.stringify(treeData)]);
      await client.query(
        `INSERT INTO content_topic_translations(topic_id, language_code, question, tree_data, status)
         VALUES ($1, $2, $3, '{}'::jsonb, 'published')
         ON CONFLICT (topic_id, language_code) DO UPDATE SET question = EXCLUDED.question,
           status = 'published', updated_at = now()`,
        [materialTopicId, language, draft.rows[0].title]);
    }
    await client.query('DELETE FROM content_lesson_drafts WHERE lesson_id = $1 AND language_code = $2', [lessonId, language]);
    await client.query('COMMIT');
    return {published: true};
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

export async function createLessonDraft(pool, {topicId, language = 'en', title, content, accountId}) {
  if (!LANGUAGES.includes(language)) throw new Error('Select a supported language.');
  if (!String(title ?? '').trim()) throw new Error('Lesson title is required.');
  if (typeof content !== 'string') throw new Error('Lesson content must be text.');
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const topic = await client.query(
      `SELECT t.level, tr.tree_data FROM content_topics t
       JOIN content_topic_translations tr ON tr.topic_id = t.topic_id
       WHERE t.topic_id = $1 AND t.visible_in_tree = true AND t.status = 'published'
         AND tr.language_code = $2 AND tr.status = 'published' FOR UPDATE`, [topicId, language]);
    if (!topic.rowCount) throw new Error('Choose a published topic in the selected language.');
    const treeData = parseJson(topic.rows[0].tree_data) ?? {};
    const lessonNumber = Math.max(1, Number(treeData.lessonCount) || 1) + 1;
    const inserted = await client.query(
      `INSERT INTO content_lessons(topic_id, lesson_number) VALUES ($1, $2)
       ON CONFLICT (topic_id, lesson_number) DO UPDATE SET topic_id = EXCLUDED.topic_id
       RETURNING id`, [topicId, lessonNumber]);
    const existingDraft = await client.query(
      `SELECT material_topic_id FROM content_lesson_drafts
       WHERE lesson_id = $1 AND language_code = $2 FOR UPDATE`,
      [inserted.rows[0].id, language]);
    let materialId = existingDraft.rows[0]?.material_topic_id;
    if (!materialId) {
      materialId = `lesson-material-${randomUUID()}`;
      await client.query(
        `INSERT INTO content_topics(topic_id, parent_topic_id, tree_position, level, lesson_count,
          visible_in_tree, status, metadata)
         VALUES ($1, NULL, 0, $2, 1, false, 'published', '{"lessonMaterial":true}'::jsonb)`,
        [materialId, Number(topic.rows[0].level) + 1]);
      await client.query(
        `INSERT INTO content_topic_translations(topic_id, language_code, question, tree_data)
         VALUES ($1, $2, $3, $4::jsonb)`,
        [materialId, language, title.trim(), JSON.stringify({
          parentId: null, level: Number(topic.rows[0].level) + 1,
          children: [], lessonCount: 1, extraLessons: [], metadata: {lessonMaterial: true},
        })]);
    }
    await client.query(
      `INSERT INTO content_lesson_drafts(lesson_id, language_code, material_topic_id, title, content, updated_by)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (lesson_id, language_code) DO UPDATE SET
         material_topic_id = EXCLUDED.material_topic_id, title = EXCLUDED.title,
         content = EXCLUDED.content, updated_by = EXCLUDED.updated_by, updated_at = now()`,
      [inserted.rows[0].id, language, materialId, title.trim(), content, accountId]);
    await client.query('COMMIT');
    return {id: inserted.rows[0].id, lessonNumber, status: 'draft'};
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

export async function saveExercise(pool, {
  lessonId, exerciseId, language, exerciseType, payload, publish = false, accountId,
}) {
  if (!LANGUAGES.includes(language)) throw new Error('Select a supported language.');
  validateExercisePayload(exerciseType, payload);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const lesson = await client.query('SELECT id FROM content_lessons WHERE id = $1 FOR UPDATE', [lessonId]);
    if (!lesson.rowCount) throw new Error('Lesson not found.');
    let id = exerciseId;
    let position = null;
    if (id) {
      const existing = await client.query(
        'SELECT id, lesson_id, language_code, position, exercise_type, status, exercise_json FROM content_exercises WHERE id = $1 FOR UPDATE', [id]);
      if (!existing.rowCount || existing.rows[0].lesson_id !== lessonId) throw new Error('Exercise not found in this lesson.');
      const row = existing.rows[0];
      position = Number(row.position);
      if (row.language_code !== language) {
        if (row.exercise_type !== exerciseType) throw new Error('The translated exercise must retain the source interaction type.');
        id = null;
      } else if (row.exercise_type !== exerciseType) {
        throw new Error('Exercise type cannot be changed after creation. Create a new exercise instead.');
      }
    }
    if (!id) {
      if (position == null) {
        const next = await client.query(
          'SELECT COALESCE(MAX(position), -1)::int + 1 AS n FROM content_exercises WHERE lesson_id = $1 AND language_code = $2',
          [lessonId, language]);
        position = Number(next.rows[0].n);
      }
      const created = await client.query(
        `INSERT INTO content_exercises(lesson_id, language_code, position, exercise_type, exercise_json, status)
         VALUES ($1, $2, $3, $4, $5::jsonb, $6) RETURNING id`,
        [lessonId, language, position, exerciseType, JSON.stringify(payload), publish ? 'published' : 'draft']);
      id = created.rows[0].id;
    }
    if (publish) {
      const current = await client.query(
        'SELECT exercise_json, status FROM content_exercises WHERE id = $1 FOR UPDATE', [id]);
      const revision = await client.query(
        `SELECT COALESCE(MAX(revision_number), 0)::int AS revision FROM content_revisions
         WHERE entity_type = 'exercise' AND entity_id = $1 AND language_code = $2`, [id, language]);
      await client.query(
        `INSERT INTO content_revisions(entity_type, entity_id, language_code, revision_number,
          status, snapshot, changed_by) VALUES ('exercise', $1, $2, $3, 'published', $4::jsonb, $5)`,
        [id, language, Number(revision.rows[0].revision) + 1,
          JSON.stringify(current.rows[0].status === 'published' ? parseJson(current.rows[0].exercise_json) : payload), accountId]);
      await client.query(
        `UPDATE content_exercises SET exercise_json = $2::jsonb, status = 'published', updated_at = now()
         WHERE id = $1`, [id, JSON.stringify(payload)]);
      await client.query('DELETE FROM content_exercise_drafts WHERE exercise_id = $1 AND language_code = $2', [id, language]);
    } else {
      await client.query(
        `INSERT INTO content_exercise_drafts(exercise_id, language_code, exercise_json, updated_by)
         VALUES ($1, $2, $3::jsonb, $4)
         ON CONFLICT (exercise_id, language_code) DO UPDATE SET exercise_json = EXCLUDED.exercise_json,
           updated_by = EXCLUDED.updated_by, updated_at = now()`, [id, language, JSON.stringify(payload), accountId]);
    }
    await client.query('COMMIT');
    return {id, status: publish ? 'published' : 'draft'};
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

export function supportedExerciseTypes() { return [...EXERCISE_TYPES]; }

export async function listContentRevisions(pool, entityType, entityId, language) {
  if (!['lesson', 'exercise'].includes(entityType) || !LANGUAGES.includes(language)) {
    throw new Error('Choose a valid revision type and language.');
  }
  const result = await pool.query(
    `SELECT id, revision_number, status, snapshot, created_at FROM content_revisions
     WHERE entity_type = $1 AND entity_id = $2 AND language_code = $3
     ORDER BY revision_number DESC LIMIT 30`, [entityType, entityId, language]);
  return result.rows.map((row) => ({
    id: String(row.id), number: Number(row.revision_number), status: row.status,
    snapshot: parseJson(row.snapshot), createdAt: row.created_at,
  }));
}

export async function restoreContentRevision(pool, {entityType, entityId, language, revisionId, accountId}) {
  if (!['lesson', 'exercise'].includes(entityType) || !LANGUAGES.includes(language)) {
    throw new Error('Choose a valid revision type and language.');
  }
  const result = await pool.query(
    `SELECT snapshot FROM content_revisions
     WHERE id = $1 AND entity_type = $2 AND entity_id = $3 AND language_code = $4`,
    [revisionId, entityType, entityId, language]);
  if (!result.rowCount) throw new Error('Revision not found.');
  const snapshot = parseJson(result.rows[0].snapshot);
  if (entityType === 'exercise') {
    const exercise = await pool.query('SELECT exercise_type FROM content_exercises WHERE id = $1 AND language_code = $2', [entityId, language]);
    if (!exercise.rowCount) throw new Error('Exercise not found.');
    validateExercisePayload(exercise.rows[0].exercise_type, snapshot);
    await pool.query(
      `INSERT INTO content_exercise_drafts(exercise_id, language_code, exercise_json, updated_by)
       VALUES ($1, $2, $3::jsonb, $4)
       ON CONFLICT (exercise_id, language_code) DO UPDATE SET
         exercise_json = EXCLUDED.exercise_json, updated_by = EXCLUDED.updated_by, updated_at = now()`,
      [entityId, language, JSON.stringify(snapshot), accountId]);
  } else {
    if (!snapshot.title || typeof snapshot.content !== 'string') throw new Error('The saved lesson version is invalid.');
    await pool.query(
      `INSERT INTO content_lesson_drafts(lesson_id, language_code, material_topic_id, title, content, updated_by)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (lesson_id, language_code) DO UPDATE SET
         material_topic_id = EXCLUDED.material_topic_id, title = EXCLUDED.title,
         content = EXCLUDED.content, updated_by = EXCLUDED.updated_by, updated_at = now()`,
      [entityId, language, snapshot.material_topic_id, snapshot.title, snapshot.content, accountId]);
  }
  return {restoredAsDraft: true};
}
