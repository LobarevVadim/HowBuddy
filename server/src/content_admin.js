import {randomUUID} from 'node:crypto';
import {EXERCISE_TYPES, validateExercisePayload} from './normalized_lesson_content.js';

const LANGUAGES = ['en', 'fr', 'es', 'hi', 'ru'];
const parseJson = (value) => typeof value === 'string' ? JSON.parse(value) : value;

export async function getContentAdminState(pool) {
  const normalized = await pool.query(`SELECT
      (SELECT COUNT(*)::int FROM content_topics) AS topics,
      (SELECT COUNT(*)::int FROM content_lessons) AS lessons,
      (SELECT COUNT(*)::int FROM content_exercises) AS exercises,
      (SELECT COUNT(DISTINCT language_code)::int FROM content_exercises) AS exercise_languages,
      (SELECT array_agg(DISTINCT language_code ORDER BY language_code)
       FROM content_lesson_translations) AS languages`);
  const row = normalized.rows[0];
  return {
    ready: Number(row.topics) > 0,
    languages: row.languages ?? [],
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

export async function getTopicForTranslation(pool, topicId, language) {
  if (!LANGUAGES.includes(language)) throw new Error('Select a supported language.');
  const topicResult = await pool.query(
    `SELECT t.topic_id, t.level, tr.question, tr.tree_data
     FROM content_topics t
     JOIN content_topic_translations tr ON tr.topic_id = t.topic_id
     WHERE t.topic_id = $1 AND t.visible_in_tree = true AND t.status = 'published'
       AND tr.language_code = $2 AND tr.status = 'published'`, [topicId, language]);
  if (!topicResult.rowCount) throw new Error('Choose a published topic in the selected language.');
  const lessonResult = await pool.query(
    `SELECT l.id, l.lesson_number, tr.material_topic_id, tr.title, tr.content
     FROM content_lessons l
     JOIN content_lesson_translations tr ON tr.lesson_id = l.id
     WHERE l.topic_id = $1 AND tr.language_code = $2 AND tr.status = 'published'
     ORDER BY l.lesson_number`, [topicId, language]);
  const lessonIds = lessonResult.rows.map((lesson) => lesson.id);
  const exerciseResult = lessonIds.length
    ? await pool.query(
        `SELECT id, lesson_id, position, exercise_type, exercise_json
         FROM content_exercises WHERE lesson_id = ANY($1::uuid[])
           AND language_code = $2 AND status = 'published'
         ORDER BY lesson_id, position`, [lessonIds, language])
    : {rows: []};
  const exercisesByLesson = new Map();
  for (const row of exerciseResult.rows) {
    const items = exercisesByLesson.get(row.lesson_id) ?? [];
    items.push({
      id: row.id,
      position: Number(row.position),
      type: row.exercise_type,
      payload: parseJson(row.exercise_json),
    });
    exercisesByLesson.set(row.lesson_id, items);
  }
  const topic = topicResult.rows[0];
  return {
    id: topic.topic_id,
    level: Number(topic.level),
    question: topic.question,
    treeData: parseJson(topic.tree_data) ?? {},
    lessons: lessonResult.rows.map((lesson) => ({
      id: lesson.id,
      lessonNumber: Number(lesson.lesson_number),
      materialTopicId: lesson.material_topic_id,
      title: lesson.title,
      content: lesson.content,
      exercises: exercisesByLesson.get(lesson.id) ?? [],
    })),
  };
}

export async function synchronizeTopicTranslations(pool, {topic, sourceLanguage, translationsByLanguage, accountId}) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const lock = await client.query(
      'SELECT topic_id FROM content_topics WHERE topic_id = $1 AND visible_in_tree = true FOR UPDATE',
      [topic.id]);
    if (!lock.rowCount) throw new Error('Topic not found.');
    const lockedLessons = await client.query(
      `SELECT l.id FROM content_lessons l
       JOIN content_lesson_translations tr ON tr.lesson_id = l.id
       WHERE l.topic_id = $1 AND tr.language_code = $2 AND tr.status = 'published'
       ORDER BY l.lesson_number FOR UPDATE OF l`, [topic.id, sourceLanguage]);
    const lockedLessonIds = lockedLessons.rows.map((row) => row.id).sort();
    const sourceLessonIds = topic.lessons.map((lesson) => lesson.id).sort();
    if (lockedLessonIds.length !== sourceLessonIds.length ||
        lockedLessonIds.some((id, index) => id !== sourceLessonIds[index])) {
      throw new Error('Topic lesson list changed during synchronization. Refresh the editor and retry.');
    }
    for (const language of LANGUAGES) {
      if (language === sourceLanguage) continue;
      const localized = translationsByLanguage?.[language];
      if (!localized) throw new Error(`Translation is missing for ${language.toUpperCase()}.`);
      const existingTopic = await client.query(
        `SELECT tree_data FROM content_topic_translations
         WHERE topic_id = $1 AND language_code = $2 FOR UPDATE`, [topic.id, language]);
      const treeData = existingTopic.rowCount
        ? parseJson(existingTopic.rows[0].tree_data) ?? {}
        : topic.treeData;
      await client.query(
        `INSERT INTO content_topic_translations(topic_id, language_code, question, tree_data, status)
         VALUES ($1, $2, $3, $4::jsonb, 'published')
         ON CONFLICT (topic_id, language_code) DO UPDATE SET
           question = EXCLUDED.question, status = 'published', updated_at = now()`,
        [topic.id, language, localized.question, JSON.stringify(treeData)]);

      for (const lesson of localized.lessons) {
        const sourceLesson = topic.lessons.find((item) => item.id === lesson.id);
        if (!sourceLesson) throw new Error('Topic lesson list changed during synchronization.');
        const currentLesson = await client.query(
          `SELECT material_topic_id, title, content FROM content_lesson_translations
           WHERE lesson_id = $1 AND language_code = $2 FOR UPDATE`, [lesson.id, language]);
        if (currentLesson.rowCount) {
          await nextRevision(client, 'lesson', lesson.id, language, currentLesson.rows[0], accountId);
        }
        const materialTopicId = currentLesson.rows[0]?.material_topic_id ?? sourceLesson.materialTopicId;
        if (materialTopicId !== topic.id) {
          await client.query(
            `INSERT INTO content_topic_translations(topic_id, language_code, question, tree_data, status)
             VALUES ($1, $2, $3, $4::jsonb, 'published')
             ON CONFLICT (topic_id, language_code) DO UPDATE SET
               question = EXCLUDED.question, status = 'published', updated_at = now()`,
            [materialTopicId, language, lesson.title, JSON.stringify({
              parentId: null, level: topic.level + 1, children: [], lessonCount: 1,
              extraLessons: [], metadata: {lessonMaterial: true},
            })]);
        }
        await client.query(
          `INSERT INTO content_lesson_translations
            (lesson_id, language_code, material_topic_id, title, content, status)
           VALUES ($1, $2, $3, $4, $5, 'published')
           ON CONFLICT (lesson_id, language_code) DO UPDATE SET
             material_topic_id = EXCLUDED.material_topic_id, title = EXCLUDED.title,
             content = EXCLUDED.content, status = 'published', updated_at = now()`,
          [lesson.id, language, materialTopicId, lesson.title, lesson.content]);

        for (const exercise of lesson.exercises) {
          validateExercisePayload(exercise.type, exercise.payload);
          const current = await client.query(
            `SELECT id, exercise_json FROM content_exercises
             WHERE lesson_id = $1 AND language_code = $2 AND position = $3 FOR UPDATE`,
            [lesson.id, language, exercise.position]);
          if (current.rowCount) {
            await nextRevision(client, 'exercise', current.rows[0].id, language,
              parseJson(current.rows[0].exercise_json), accountId);
            await client.query(
              `UPDATE content_exercises SET exercise_type = $2, exercise_json = $3::jsonb,
               status = 'published', updated_at = now() WHERE id = $1`,
              [current.rows[0].id, exercise.type, JSON.stringify(exercise.payload)]);
          } else {
            await client.query(
              `INSERT INTO content_exercises(lesson_id, language_code, position, exercise_type, exercise_json, status)
               VALUES ($1, $2, $3, $4, $5::jsonb, 'published')`,
              [lesson.id, language, exercise.position, exercise.type, JSON.stringify(exercise.payload)]);
          }
        }
      }

      const publishedLessons = await client.query(
        `SELECT tr.material_topic_id FROM content_lessons l
         JOIN content_lesson_translations tr ON tr.lesson_id = l.id
         WHERE l.topic_id = $1 AND tr.language_code = $2 AND tr.status = 'published'
         ORDER BY l.lesson_number`, [topic.id, language]);
      const synchronizedTree = {
        ...treeData,
        lessonCount: Math.max(1, publishedLessons.rowCount),
        extraLessons: publishedLessons.rows.slice(1).map((row) => row.material_topic_id),
      };
      await client.query(
        `UPDATE content_topic_translations SET tree_data = $3::jsonb, updated_at = now()
         WHERE topic_id = $1 AND language_code = $2`,
        [topic.id, language, JSON.stringify(synchronizedTree)]);
    }
    await client.query('COMMIT');
    return {published: true, languages: LANGUAGES};
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

export async function listContentLessons(pool, topicId, language = 'en') {
  const lang = LANGUAGES.includes(language) ? language : 'en';
  const result = await pool.query(
    `SELECT l.id, l.topic_id, l.lesson_number,
            COALESCE(own.material_topic_id, english.material_topic_id) AS material_topic_id,
            COALESCE(own.title, english.title, '') AS title,
            COALESCE(own.content, english.content, '') AS content,
            COALESCE(own.status, english.status, 'untranslated') AS status,
            (SELECT COUNT(*)::int FROM content_exercises e
             WHERE e.lesson_id = l.id AND e.language_code =
               COALESCE(own.language_code, english.language_code, $2)) AS exercise_count
     FROM content_lessons l
     LEFT JOIN content_lesson_translations own
       ON own.lesson_id = l.id AND own.language_code = $2 AND own.status = 'published'
     LEFT JOIN content_lesson_translations english
       ON english.lesson_id = l.id AND english.language_code = 'en' AND english.status = 'published'
     WHERE l.topic_id = $1 AND (own.lesson_id IS NOT NULL OR english.lesson_id IS NOT NULL)
     ORDER BY l.lesson_number`, [topicId, lang]);
  return result.rows.map((row, index) => ({
    id: row.id,
    topicId: row.topic_id,
    // Hide gaps left by legacy planned lesson slots; editor ordering follows
    // the published lesson sequence that the learner sees.
    lessonNumber: index + 1,
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
            COALESCE(own.material_topic_id, english.material_topic_id) AS material_topic_id,
            COALESCE(own.title, english.title, '') AS title,
            COALESCE(own.content, english.content, '') AS content,
            COALESCE(own.language_code, english.language_code, $2) AS content_language,
            COALESCE(own.status, english.status, 'untranslated') AS status
     FROM content_lessons l
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
    exercises,
  };
}

async function loadAdminExercises(pool, lessonId, language) {
  const result = await pool.query(
    `SELECT e.id, e.position, e.exercise_type, e.status,
            e.exercise_json
     FROM content_exercises e
     WHERE e.lesson_id = $1 AND e.language_code = $2
     ORDER BY e.position`, [lessonId, language]);
  return result.rows.map((row) => ({
    id: row.id,
    position: Number(row.position),
    type: row.exercise_type,
    language,
    isFallback: false,
    status: row.status,
    payload: parseJson(row.exercise_json),
  }));
}

async function nextRevision(client, type, id, language, snapshot, accountId) {
  const result = await client.query(
    `SELECT COALESCE(MAX(revision_number), 0)::int AS revision FROM content_revisions
     WHERE entity_type = $1 AND entity_id = $2 AND language_code = $3`, [type, id, language]);
  await client.query(
    `INSERT INTO content_revisions(entity_type, entity_id, language_code, revision_number,
      status, snapshot, changed_by) VALUES ($1, $2, $3, $4, 'published', $5::jsonb, $6)`,
    [type, id, language, Number(result.rows[0].revision) + 1, JSON.stringify(snapshot), accountId]);
}

async function publishLessonLanguage(client, {lesson, language, title, content, accountId, sharedMaterialId}) {
  const current = await client.query(
    `SELECT material_topic_id, title, content FROM content_lesson_translations
     WHERE lesson_id = $1 AND language_code = $2 FOR UPDATE`, [lesson.id, language]);
  if (current.rowCount) await nextRevision(client, 'lesson', lesson.id, language, current.rows[0], accountId);
  const topicTranslation = await client.query(
    `SELECT tree_data FROM content_topic_translations
     WHERE topic_id = $1 AND language_code = $2 AND status = 'published' FOR UPDATE`,
    [lesson.topic_id, language]);
  if (!topicTranslation.rowCount) throw new Error(`The ${language.toUpperCase()} topic translation is missing.`);
  const treeData = parseJson(topicTranslation.rows[0].tree_data) ?? {};
  const existingMaterial = await client.query(
    `SELECT material_topic_id FROM content_lesson_translations
     WHERE lesson_id = $1
     ORDER BY (language_code = $2) DESC, (language_code = 'en') DESC
     LIMIT 1`, [lesson.id, language]);
  const materialTopicId = Number(lesson.lesson_number) === 1
    ? lesson.topic_id
    : current.rows[0]?.material_topic_id ?? existingMaterial.rows[0]?.material_topic_id ?? sharedMaterialId;
  if (!materialTopicId) throw new Error('Could not resolve the lesson content node.');
  if (materialTopicId !== lesson.topic_id) {
    if (materialTopicId === sharedMaterialId) await client.query(
      `INSERT INTO content_topics(topic_id, parent_topic_id, tree_position, level, lesson_count,
        visible_in_tree, status, metadata)
       VALUES ($1, NULL, 0, $2, 1, false, 'published', '{"lessonMaterial":true}'::jsonb)
       ON CONFLICT (topic_id) DO NOTHING`,
      [materialTopicId, Number(lesson.level) + 1]);
    await client.query(
      `INSERT INTO content_topic_translations(topic_id, language_code, question, tree_data, status)
       VALUES ($1, $2, $3, $4::jsonb, 'published')
       ON CONFLICT (topic_id, language_code) DO UPDATE SET question = EXCLUDED.question,
         status = 'published', updated_at = now()`,
      [materialTopicId, language, title, JSON.stringify({
        parentId: null, level: Number(lesson.level) + 1, children: [], lessonCount: 1,
        extraLessons: [], metadata: {lessonMaterial: true},
      })]);
  }
  await client.query(
    `INSERT INTO content_lesson_translations
      (lesson_id, language_code, material_topic_id, title, content, status)
     VALUES ($1, $2, $3, $4, $5, 'published')
     ON CONFLICT (lesson_id, language_code) DO UPDATE SET
       material_topic_id = EXCLUDED.material_topic_id, title = EXCLUDED.title,
       content = EXCLUDED.content, status = 'published', updated_at = now()`,
    [lesson.id, language, materialTopicId, title, content]);

  const publishedLessons = await client.query(
    `SELECT tr.material_topic_id
     FROM content_lessons l
     JOIN content_lesson_translations tr ON tr.lesson_id = l.id
     WHERE l.topic_id = $1 AND tr.language_code = $2 AND tr.status = 'published'
     ORDER BY l.lesson_number`, [lesson.topic_id, language]);
  treeData.lessonCount = Math.max(1, publishedLessons.rowCount);
  treeData.extraLessons = publishedLessons.rows.slice(1).map((row) => row.material_topic_id);
  await client.query(
    `UPDATE content_topic_translations SET tree_data = $3::jsonb, updated_at = now()
     WHERE topic_id = $1 AND language_code = $2`,
    [lesson.topic_id, language, JSON.stringify(treeData)]);
}

export async function saveLesson(pool, {lessonId, language, allLanguages, translationsByLanguage, title, content, accountId}) {
  if (!LANGUAGES.includes(language)) throw new Error('Select a supported language.');
  if (!String(title ?? '').trim()) throw new Error('Lesson title is required.');
  if (typeof content !== 'string') throw new Error('Lesson content must be text.');
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await client.query(
      `SELECT l.id, l.topic_id, l.lesson_number, t.level
       FROM content_lessons l JOIN content_topics t ON t.topic_id = l.topic_id
       WHERE l.id = $1 FOR UPDATE`, [lessonId]);
    if (!result.rowCount) throw new Error('Lesson not found.');
    const lesson = result.rows[0];
    const languages = allLanguages ? LANGUAGES : [language];
    const sharedMaterialId = Number(lesson.lesson_number) > 1 ? `lesson-material-${randomUUID()}` : null;
    for (const code of languages) {
      const localized = translationsByLanguage?.[code] ?? {title, content};
      await publishLessonLanguage(client, {
        lesson, language: code, title: String(localized.title).trim(),
        content: localized.content, accountId, sharedMaterialId,
      });
    }
    await client.query('COMMIT');
    return {published: true, languages};
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

export async function createLesson(pool, {topicId, language, allLanguages, translationsByLanguage, title, content, accountId}) {
  if (!LANGUAGES.includes(language)) throw new Error('Select a supported language.');
  if (!String(title ?? '').trim()) throw new Error('Lesson title is required.');
  if (typeof content !== 'string') throw new Error('Lesson content must be text.');
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const topic = await client.query(
      `SELECT t.level FROM content_topics t
       JOIN content_topic_translations tr ON tr.topic_id = t.topic_id
       WHERE t.topic_id = $1 AND t.visible_in_tree = true AND t.status = 'published'
         AND tr.language_code = $2 AND tr.status = 'published' FOR UPDATE`, [topicId, language]);
    if (!topic.rowCount) throw new Error('Choose a published topic in the selected language.');
    const numberResult = await client.query(
      'SELECT COALESCE(MAX(lesson_number), 0)::int + 1 AS n FROM content_lessons WHERE topic_id = $1', [topicId]);
    const lessonNumber = Number(numberResult.rows[0].n);
    const inserted = await client.query(
      'INSERT INTO content_lessons(topic_id, lesson_number) VALUES ($1, $2) RETURNING id', [topicId, lessonNumber]);
    const lesson = {id: inserted.rows[0].id, topic_id: topicId, lesson_number: lessonNumber, level: Number(topic.rows[0].level)};
    const languages = allLanguages ? LANGUAGES : [language];
    const sharedMaterialId = lessonNumber > 1 ? `lesson-material-${randomUUID()}` : null;
    for (const code of languages) {
      const localized = translationsByLanguage?.[code] ?? {title, content};
      await publishLessonLanguage(client, {
        lesson, language: code, title: String(localized.title).trim(),
        content: localized.content, accountId, sharedMaterialId,
      });
    }
    await client.query('COMMIT');
    return {id: lesson.id, lessonNumber, published: true, languages};
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

export async function saveExercise(pool, {
  lessonId, exerciseId, language, allLanguages = false, payloadsByLanguage, exerciseType, payload, accountId,
}) {
  if (!LANGUAGES.includes(language)) throw new Error('Select a supported language.');
  validateExercisePayload(exerciseType, payload);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const lesson = await client.query('SELECT id FROM content_lessons WHERE id = $1 FOR UPDATE', [lessonId]);
    if (!lesson.rowCount) throw new Error('Lesson not found.');
    let source = null;
    if (exerciseId) {
      const existing = await client.query(
        'SELECT id, lesson_id, language_code, position, exercise_type, status, exercise_json FROM content_exercises WHERE id = $1 FOR UPDATE', [exerciseId]);
      if (!existing.rowCount || existing.rows[0].lesson_id !== lessonId) throw new Error('Exercise not found in this lesson.');
      source = existing.rows[0];
      if (source.exercise_type !== exerciseType) throw new Error('Exercise type cannot be changed after creation. Create a new exercise instead.');
    }
    let position;
    if (source) position = Number(source.position);
    else {
      const next = await client.query(
        `SELECT COALESCE(MAX(position), -1)::int + 1 AS n FROM content_exercises
         WHERE lesson_id = $1 AND language_code = ANY($2::text[])`,
        [lessonId, allLanguages ? LANGUAGES : [language]]);
      position = Number(next.rows[0].n);
    }
    const languages = allLanguages ? LANGUAGES : [language];
    let selectedId = null;
    for (const code of languages) {
      const current = await client.query(
        `SELECT id, exercise_type, exercise_json FROM content_exercises
         WHERE lesson_id = $1 AND language_code = $2 AND position = $3 FOR UPDATE`,
        [lessonId, code, position]);
      const localizedPayload = payloadsByLanguage?.[code] ?? payload;
      validateExercisePayload(exerciseType, localizedPayload);
      if (current.rowCount) {
        const row = current.rows[0];
        if (row.exercise_type !== exerciseType) {
          throw new Error(`The ${code.toUpperCase()} exercise at this position has a different type.`);
        }
        await nextRevision(client, 'exercise', row.id, code, parseJson(row.exercise_json), accountId);
        await client.query(
          `UPDATE content_exercises SET exercise_json = $2::jsonb, status = 'published', updated_at = now()
          WHERE id = $1`, [row.id, JSON.stringify(localizedPayload)]);
        if (code === language) selectedId = row.id;
      } else {
        const created = await client.query(
          `INSERT INTO content_exercises(lesson_id, language_code, position, exercise_type, exercise_json, status)
           VALUES ($1, $2, $3, $4, $5::jsonb, 'published') RETURNING id`,
          [lessonId, code, position, exerciseType, JSON.stringify(localizedPayload)]);
        if (code === language) selectedId = created.rows[0].id;
      }
    }
    await client.query('COMMIT');
    return {id: selectedId, status: 'published', languages, position};
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

export function supportedExerciseTypes() { return [...EXERCISE_TYPES]; }

export async function deleteExercise(pool, {lessonId, exerciseId}) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await client.query(
      'SELECT id FROM content_exercises WHERE id = $1 AND lesson_id = $2 FOR UPDATE',
      [exerciseId, lessonId]);
    if (!result.rowCount) throw new Error('Exercise not found in this lesson.');
    await client.query(
      "DELETE FROM content_revisions WHERE entity_type = 'exercise' AND entity_id = $1", [exerciseId]);
    await client.query('DELETE FROM content_exercises WHERE id = $1', [exerciseId]);
    await client.query('COMMIT');
    return {deleted: true};
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

export async function deleteLesson(pool, {lessonId}) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const found = await client.query(
      'SELECT id, topic_id, lesson_number FROM content_lessons WHERE id = $1 FOR UPDATE', [lessonId]);
    if (!found.rowCount) throw new Error('Lesson not found.');
    const lesson = found.rows[0];
    const exercises = await client.query('SELECT id FROM content_exercises WHERE lesson_id = $1', [lessonId]);
    const oldMaterials = await client.query(
      'SELECT material_topic_id FROM content_lesson_translations WHERE lesson_id = $1', [lessonId]);
    await client.query("DELETE FROM content_revisions WHERE entity_type = 'lesson' AND entity_id = $1", [lessonId]);
    if (exercises.rowCount) await client.query(
      "DELETE FROM content_revisions WHERE entity_type = 'exercise' AND entity_id = ANY($1::text[])",
      [exercises.rows.map((row) => row.id)]);
    await client.query('DELETE FROM content_lessons WHERE id = $1', [lessonId]);
    await client.query(
      `UPDATE content_lessons SET lesson_number = lesson_number + 100000
       WHERE topic_id = $1 AND lesson_number > $2`, [lesson.topic_id, lesson.lesson_number]);
    await client.query(
      `UPDATE content_lessons SET lesson_number = lesson_number - 100001
       WHERE topic_id = $1 AND lesson_number > 100000`, [lesson.topic_id]);
    const remaining = await client.query(
      `SELECT l.id, l.lesson_number, tr.language_code, tr.material_topic_id
       FROM content_lessons l LEFT JOIN content_lesson_translations tr ON tr.lesson_id = l.id
       WHERE l.topic_id = $1 ORDER BY l.lesson_number`, [lesson.topic_id]);
    const byLanguage = new Map(LANGUAGES.map((language) => [language, []]));
    for (const row of remaining.rows) {
      if (row.language_code) byLanguage.get(row.language_code)?.push(row);
    }
    for (const language of LANGUAGES) {
      const rows = byLanguage.get(language);
      const english = byLanguage.get('en');
      for (const row of rows) {
        if (Number(row.lesson_number) === 1 && row.material_topic_id !== lesson.topic_id) {
          await client.query(
            'UPDATE content_lesson_translations SET material_topic_id = $2 WHERE lesson_id = $1 AND language_code = $3',
            [row.id, lesson.topic_id, language]);
        }
      }
      const topicResult = await client.query(
        'SELECT tree_data FROM content_topic_translations WHERE topic_id = $1 AND language_code = $2 FOR UPDATE',
        [lesson.topic_id, language]);
      if (!topicResult.rowCount) continue;
      const treeData = parseJson(topicResult.rows[0].tree_data) ?? {};
      const extraLessons = [];
      for (const row of rows) {
        if (Number(row.lesson_number) < 2) continue;
        const material = row.material_topic_id ?? english.find((item) => item.id === row.id)?.material_topic_id;
        if (material) extraLessons[Number(row.lesson_number) - 2] = material;
      }
      treeData.extraLessons = extraLessons;
      treeData.lessonCount = Math.max(1, rows.length);
      await client.query(
        'UPDATE content_topic_translations SET tree_data = $3::jsonb, updated_at = now() WHERE topic_id = $1 AND language_code = $2',
        [lesson.topic_id, language, JSON.stringify(treeData)]);
    }
    const removableMaterials = [...new Set(oldMaterials.rows.map((row) => row.material_topic_id).filter(Boolean))];
    if (removableMaterials.length) await client.query(
      `DELETE FROM content_topics t WHERE t.topic_id = ANY($1::text[]) AND t.visible_in_tree = false
       AND NOT EXISTS (SELECT 1 FROM content_lesson_translations l WHERE l.material_topic_id = t.topic_id)`,
      [removableMaterials]);
    await client.query('COMMIT');
    return {deleted: true};
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

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
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await client.query(
    `SELECT snapshot FROM content_revisions
     WHERE id = $1 AND entity_type = $2 AND entity_id = $3 AND language_code = $4`,
    [revisionId, entityType, entityId, language]);
    if (!result.rowCount) throw new Error('Revision not found.');
    const snapshot = parseJson(result.rows[0].snapshot);
    if (entityType === 'exercise') {
      const exercise = await client.query('SELECT exercise_type, exercise_json FROM content_exercises WHERE id = $1 AND language_code = $2 FOR UPDATE', [entityId, language]);
      if (!exercise.rowCount) throw new Error('Exercise not found.');
      validateExercisePayload(exercise.rows[0].exercise_type, snapshot);
      await nextRevision(client, 'exercise', entityId, language, parseJson(exercise.rows[0].exercise_json), accountId);
      await client.query(
        'UPDATE content_exercises SET exercise_json = $2::jsonb, status = \'published\', updated_at = now() WHERE id = $1',
        [entityId, JSON.stringify(snapshot)]);
    } else {
      if (!snapshot.title || typeof snapshot.content !== 'string') throw new Error('The saved lesson version is invalid.');
      await nextRevision(client, 'lesson', entityId, language, snapshot, accountId);
      await client.query(
        `UPDATE content_lesson_translations SET material_topic_id = $3, title = $4, content = $5,
          status = 'published', updated_at = now() WHERE lesson_id = $1 AND language_code = $2`,
        [entityId, language, snapshot.material_topic_id, snapshot.title, snapshot.content]);
    }
    await client.query('COMMIT');
    return {published: true};
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}
