import {LESSON_LANGUAGES, validateLessonContent} from './lesson_content_store.js';

export const EXERCISE_TYPES = Object.freeze([
  'singleChoice', 'multipleSelect', 'shortAnswer', 'orderSteps', 'matching',
  'fillInTheBlank', 'trueFalse', 'spotTheMistake', 'categorization',
  'causeAndEffect', 'compareAndContrast', 'buildTheProcess',
]);

const normalizedNodeFields = new Set([
  'id', 'parentId', 'question', 'content', 'level', 'children', 'lessonCount',
  'extraLessons', 'exercises',
]);

function parseJson(value) {
  return typeof value === 'string' ? JSON.parse(value) : value;
}

function translationsById(rows, idColumn, language) {
  const byId = new Map();
  for (const row of rows) {
    const current = byId.get(row[idColumn]);
    if (!current || row.language_code === language) byId.set(row[idColumn], row);
  }
  return byId;
}

export function validateExercisePayload(type, payload) {
  if (!EXERCISE_TYPES.includes(type)) throw new Error('Select a supported exercise type.');
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    throw new Error('Exercise content must be an object.');
  }
  if (payload.type !== type) throw new Error('The JSON exercise type must match its selected type.');
  if (!String(payload.prompt ?? '').trim()) throw new Error('Exercise question is required.');
  if (!String(payload.explanation ?? '').trim()) throw new Error('Exercise explanation is required.');
  const list = (key) => Array.isArray(payload[key]) ? payload[key] : [];
  const answers = list('correctAnswers');
  const options = list('options');
  const order = list('correctOrder');
  const pairs = list('pairs');
  const requireValues = (condition, message) => { if (!condition) throw new Error(message); };
  switch (type) {
    case 'singleChoice':
    case 'trueFalse':
    case 'spotTheMistake':
      requireValues(options.length >= 2 && answers.length === 1,
        'Provide at least two options and exactly one correct answer.');
      break;
    case 'multipleSelect':
      requireValues(options.length >= 2 && answers.length >= 1,
        'Provide at least two options and one or more correct answers.');
      break;
    case 'shortAnswer':
      requireValues(answers.length >= 1, 'Provide at least one accepted answer.');
      break;
    case 'orderSteps':
      requireValues(order.length >= 2 && options.length >= order.length,
        'Provide the correct step order and a shuffled set of step options.');
      break;
    case 'matching':
    case 'categorization':
    case 'causeAndEffect':
      requireValues(pairs.length >= 2, 'Provide at least two matching pairs.');
      requireValues(options.length >= 2, 'Provide at least two right-side choices or categories.');
      break;
    case 'compareAndContrast':
      requireValues(pairs.length >= 2, 'Provide at least two statements to sort in the Venn diagram.');
      requireValues(list('categories').length >= 3,
        'Provide labels for both circles and their shared overlap.');
      break;
    case 'fillInTheBlank':
      requireValues(order.length >= 1 && list('paragraphParts').length === order.length + 1,
        'Provide one more paragraph segment than missing words, plus the missing words in order.');
      break;
    case 'buildTheProcess':
      requireValues(order.length >= 2 && options.length >= order.length,
        'Provide at least two process steps and a set of draggable components.');
      break;
  }
  return payload;
}

function contentTopology(content, language) {
  validateLessonContent(content, language);
  const nodes = Object.values(content.nodes);
  const ids = new Set(nodes.map((node) => node.id));
  for (const node of nodes) {
    if (node.parentId != null && !ids.has(node.parentId)) {
      throw new Error(`Content ${language} has missing parent for ${node.id}.`);
    }
    for (const childId of node.children ?? []) {
      if (!ids.has(childId)) throw new Error(`Content ${language} has missing child ${childId}.`);
    }
    for (const extraId of node.extraLessons ?? []) {
      if (!ids.has(extraId)) throw new Error(`Content ${language} has missing extra lesson ${extraId}.`);
    }
    for (const exercise of node.exercises ?? []) {
      validateExercisePayload(exercise.type, exercise);
    }
  }
  return nodes;
}

function treeDataForNode(node) {
  const metadata = Object.fromEntries(Object.entries(node).filter(([key]) => !normalizedNodeFields.has(key)));
  return {
    parentId: node.parentId ?? null,
    level: Number(node.level) || 1,
    children: node.children ?? [],
    lessonCount: Math.max(1, Number(node.lessonCount) || 1),
    extraLessons: node.extraLessons ?? [],
    metadata,
  };
}

export async function migrateLegacyLessonContent(pool) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query("SELECT pg_advisory_xact_lock(hashtext('howbuddy-normalized-content-migration'))");
    const existing = await client.query('SELECT COUNT(*)::int AS count FROM content_topics');
    if (Number(existing.rows[0].count) > 0) {
      throw new Error('Normalized content already exists; migration was not run again.');
    }
    const legacyResult = await client.query(
      'SELECT language_code, content FROM lesson_content_by_language ORDER BY language_code',
    );
    const legacy = new Map(legacyResult.rows.map((row) => [row.language_code, parseJson(row.content)]));
    const expectedLanguages = Object.keys(LESSON_LANGUAGES);
    const missing = expectedLanguages.filter((language) => !legacy.has(language));
    if (missing.length) throw new Error(`Legacy content is missing language rows: ${missing.join(', ')}.`);
    const english = legacy.get('en');
    const canonicalById = new Map();
    for (const language of ['en', ...expectedLanguages.filter((item) => item !== 'en')]) {
      for (const node of contentTopology(legacy.get(language), language)) {
        if (!canonicalById.has(node.id)) canonicalById.set(node.id, node);
      }
    }
    const canonicalNodes = [...canonicalById.values()].sort((a, b) =>
      (Number(a.level) || 1) - (Number(b.level) || 1) || a.id.localeCompare(b.id));
    const visibleIds = new Set();
    for (const language of expectedLanguages) {
      const content = legacy.get(language);
      content.roots.forEach((id) => visibleIds.add(id));
      for (const node of Object.values(content.nodes)) {
        for (const child of node.children ?? []) visibleIds.add(child);
      }
    }
    const positionById = new Map();
    for (const node of canonicalNodes) {
      const siblings = node.parentId == null
        ? english.roots
        : canonicalById.get(node.parentId)?.children ?? [];
      positionById.set(node.id, Math.max(0, siblings.indexOf(node.id)));
      await client.query(
        `INSERT INTO content_topics
          (topic_id, parent_topic_id, tree_position, level, lesson_count, visible_in_tree, metadata)
         VALUES ($1, NULL, $2, $3, $4, $5, $6::jsonb)`,
        [node.id, positionById.get(node.id), Number(node.level) || 1,
          Math.max(1, Number(node.lessonCount) || 1), visibleIds.has(node.id),
          JSON.stringify(treeDataForNode(node).metadata)],
      );
    }
    for (const node of canonicalNodes) {
      if (node.parentId != null) {
        await client.query('UPDATE content_topics SET parent_topic_id = $2 WHERE topic_id = $1', [node.id, node.parentId]);
      }
    }

    for (const language of expectedLanguages) {
      const content = legacy.get(language);
      for (const [position, rootId] of content.roots.entries()) {
        await client.query(
          'INSERT INTO content_tree_roots(language_code, tree_position, topic_id) VALUES ($1, $2, $3)',
          [language, position, rootId],
        );
      }
      for (const node of Object.values(content.nodes)) {
        await client.query(
          `INSERT INTO content_topic_translations(topic_id, language_code, question, tree_data)
           VALUES ($1, $2, $3, $4::jsonb)`,
          [node.id, language, String(node.question ?? ''), JSON.stringify(treeDataForNode(node))],
        );
      }
      const processedLessons = new Set();
      for (const topic of Object.values(content.nodes)) {
        const lessonMaterials = [topic.id, ...(topic.extraLessons ?? [])];
        for (const [index, materialTopicId] of lessonMaterials.entries()) {
          const lessonNumber = index + 1;
          const key = `${topic.id}\u0000${lessonNumber}`;
          if (processedLessons.has(key)) continue;
          processedLessons.add(key);
          const material = content.nodes[materialTopicId];
          const lessonResult = await client.query(
            `INSERT INTO content_lessons(topic_id, lesson_number) VALUES ($1, $2)
             ON CONFLICT (topic_id, lesson_number) DO UPDATE SET topic_id = EXCLUDED.topic_id
             RETURNING id`, [topic.id, lessonNumber]);
          const lessonId = lessonResult.rows[0].id;
          await client.query(
            `INSERT INTO content_lesson_translations
              (lesson_id, language_code, material_topic_id, title, content)
             VALUES ($1, $2, $3, $4, $5)`,
            [lessonId, language, materialTopicId,
              lessonNumber === 1 ? 'Core lesson' : String(material.question ?? ''),
              String(material.content ?? '')],
          );
          for (const [position, exercise] of (material.exercises ?? []).entries()) {
            validateExercisePayload(exercise.type, exercise);
            await client.query(
              `INSERT INTO content_exercises
                (lesson_id, language_code, position, exercise_type, exercise_json)
               VALUES ($1, $2, $3, $4, $5::jsonb)`,
              [lessonId, language, position, exercise.type, JSON.stringify(exercise)],
            );
          }
        }
      }
    }
    await client.query('COMMIT');
    return {languages: expectedLanguages.length, topics: canonicalNodes.length};
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

export async function normalizedContentExists(pool) {
  const result = await pool.query('SELECT EXISTS (SELECT 1 FROM content_topics) AS exists');
  return result.rows[0]?.exists === true;
}

export async function loadNormalizedLessonContent(pool, language = 'en') {
  const code = Object.hasOwn(LESSON_LANGUAGES, String(language)) ? String(language) : 'en';
  const languages = code === 'en' ? ['en'] : [code, 'en'];
  const [rootsResult, topicsResult, lessonResult, exerciseResult] = await Promise.all([
    pool.query(
      `SELECT topic_id FROM content_tree_roots WHERE language_code = $1 ORDER BY tree_position`, [code]),
    pool.query(
      `SELECT t.topic_id, t.metadata, tr.question, tr.tree_data, tr.language_code
       FROM content_topics t
       JOIN LATERAL (
         SELECT question, tree_data, language_code
         FROM content_topic_translations
         WHERE topic_id = t.topic_id AND language_code = ANY($1::text[]) AND status = 'published'
         ORDER BY (language_code = $2) DESC LIMIT 1
       ) tr ON true
       WHERE t.status = 'published'
         AND (t.visible_in_tree = true OR EXISTS (
           SELECT 1 FROM content_lesson_translations lt
           WHERE lt.material_topic_id = t.topic_id AND lt.status = 'published'
         ))`, [languages, code]),
    pool.query(
      `SELECT l.id, l.topic_id, l.lesson_number, tr.material_topic_id, tr.title, tr.content, tr.language_code
       FROM content_lessons l
       JOIN LATERAL (
         SELECT material_topic_id, title, content, language_code
         FROM content_lesson_translations
         WHERE lesson_id = l.id AND language_code = ANY($1::text[]) AND status = 'published'
         ORDER BY (language_code = $2) DESC LIMIT 1
       ) tr ON true`, [languages, code]),
    pool.query(
      `SELECT id, lesson_id, language_code, position, exercise_type, exercise_json
       FROM content_exercises WHERE language_code = ANY($1::text[]) AND status = 'published'
       ORDER BY lesson_id, language_code, position`, [languages]),
  ]);

  const nodes = {};
  for (const row of topicsResult.rows) {
    const treeData = parseJson(row.tree_data) ?? {};
    nodes[row.topic_id] = {
      ...(parseJson(row.metadata) ?? {}),
      ...(treeData.metadata ?? {}),
      id: row.topic_id,
      parentId: treeData.parentId ?? null,
      question: row.question,
      level: Number(treeData.level) || 1,
      children: Array.isArray(treeData.children) ? treeData.children : [],
      lessonCount: Math.max(1, Number(treeData.lessonCount) || 1),
      extraLessons: Array.isArray(treeData.extraLessons) ? treeData.extraLessons : [],
      content: '',
      exercises: [],
    };
  }

  const exercisesByLessonAndLanguage = new Map();
  for (const row of exerciseResult.rows) {
    const key = `${row.lesson_id}:${row.language_code}`;
    if (!exercisesByLessonAndLanguage.has(key)) exercisesByLessonAndLanguage.set(key, []);
    const exercise = parseJson(row.exercise_json);
    validateExercisePayload(row.exercise_type, exercise);
    exercisesByLessonAndLanguage.get(key).push({position: Number(row.position), exercise});
  }
  for (const lesson of lessonResult.rows) {
    const source = nodes[lesson.material_topic_id];
    if (!source) continue;
    const number = Number(lesson.lesson_number);
    if (number === 1 || !source.content) source.content = lesson.content;
    const localized = exercisesByLessonAndLanguage.get(`${lesson.id}:${lesson.language_code}`) ?? [];
    const selectedExercises = localized.map((item) => item.exercise);
    if (number === 1 || !source.exercises.length) source.exercises = selectedExercises;
  }

  let roots = rootsResult.rows.map((row) => row.topic_id);
  if (!roots.length && code !== 'en') {
    const fallbackRoots = await pool.query(
      "SELECT topic_id FROM content_tree_roots WHERE language_code = 'en' ORDER BY tree_position");
    roots = fallbackRoots.rows.map((row) => row.topic_id);
  }
  if (!roots.length) throw new Error(`No normalized lesson roots were found for ${code}.`);
  for (const root of roots) if (!nodes[root]) throw new Error(`Normalized root ${root} is missing.`);
  return validateLessonContent({version: 2, roots, nodes}, code);
}
