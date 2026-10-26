import {LESSON_LANGUAGES, validateLessonContent} from './lesson_content_store.js';

export const EXERCISE_TYPES = Object.freeze([
  'singleChoice', 'multipleSelect', 'shortAnswer', 'orderSteps', 'matching',
  'fillInTheBlank', 'trueFalse', 'spotTheMistake', 'categorization',
  'causeAndEffect', 'compareAndContrast', 'buildTheProcess',
]);

export function projectPublishedLessons(lessonRows) {
  const byTopic = new Map();
  for (const lesson of lessonRows) {
    if (!byTopic.has(lesson.topic_id)) byTopic.set(lesson.topic_id, []);
    byTopic.get(lesson.topic_id).push(lesson);
  }
  const projection = new Map();
  for (const [topicId, lessons] of byTopic) {
    lessons.sort((a, b) => Number(a.lesson_number) - Number(b.lesson_number));
    projection.set(topicId, {
      lessonCount: lessons.length,
      extraLessons: lessons.slice(1).map((lesson) => lesson.material_topic_id),
    });
  }
  return projection;
}

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
       ) tr ON true
       ORDER BY l.topic_id, l.lesson_number`, [languages, code]),
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
  for (const [topicId, projection] of projectPublishedLessons(lessonResult.rows)) {
    if (nodes[topicId]) Object.assign(nodes[topicId], projection);
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
