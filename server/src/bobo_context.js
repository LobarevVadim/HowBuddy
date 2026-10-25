function cleanText(value, limit = 1000) {
  return typeof value === 'string' ? value.slice(0, limit) : '';
}

function publishedLessons(topicNode, nodes) {
  const ids = [topicNode.id, ...(topicNode.extraLessons ?? [])];
  return ids
    .slice(0, Number(topicNode.lessonCount) || 1)
    .map((id) => nodes[id])
    .filter((lesson) => lesson && Array.isArray(lesson.exercises) && lesson.exercises.length > 0);
}

function buildTopicIndex(content) {
  const topics = [];
  const seen = new Set();
  const visit = (id) => {
    if (seen.has(id)) return;
    seen.add(id);
    const node = content.nodes[id];
    if (!node) return;
    topics.push(node);
    for (const childId of node.children ?? []) visit(childId);
  };
  for (const rootId of content.roots ?? []) visit(rootId);
  return topics;
}

export function buildBoboLessonContext({
  content,
  topicId,
  lessonId,
  exerciseIndex,
  studentAnswer,
  answerSubmitted,
  answerCorrect,
  preferredLanguage,
  progressRows,
}) {
  const topic = content.nodes[topicId];
  if (!topic) {
    const error = new Error('This lesson could not be found.');
    error.status = 404;
    throw error;
  }

  const lessons = publishedLessons(topic, content.nodes);
  const match = /^lesson-(\d{1,2})$/.exec(lessonId);
  const lessonNumber = match ? Number(match[1]) : 0;
  const lesson = lessonNumber > 0 ? lessons[lessonNumber - 1] : null;
  if (!lesson) {
    const error = new Error('This lesson is not available.');
    error.status = 404;
    throw error;
  }

  const completedByTopic = new Map(
    progressRows.map((row) => [row.topic_id, new Set(row.lesson_ids ?? [])]),
  );
  const completedForCurrentTopic = completedByTopic.get(topicId) ?? new Set();
  const completedLessons = lessons.filter((_item, index) =>
    completedForCurrentTopic.has(`lesson-${index + 1}`),
  ).length;
  const completedTopics = buildTopicIndex(content)
    .filter((node) => {
      const nodeLessons = publishedLessons(node, content.nodes);
      const completed = completedByTopic.get(node.id) ?? new Set();
      return nodeLessons.length > 0 && nodeLessons.every((_item, index) => completed.has(`lesson-${index + 1}`));
    })
    .slice(0, 30)
    .map((node) => ({id: node.id, title: cleanText(node.question, 180)}));

  let activeExercise = null;
  if (exerciseIndex !== null && exerciseIndex !== undefined) {
    if (!Number.isInteger(exerciseIndex) || exerciseIndex < 0 || exerciseIndex >= lesson.exercises.length) {
      const error = new Error('That exercise is not available.');
      error.status = 400;
      throw error;
    }
    const exercise = lesson.exercises[exerciseIndex];
    activeExercise = {
      id: `exercise-${exerciseIndex + 1}`,
      type: exercise.type,
      prompt: cleanText(exercise.prompt, 1000),
      options: (exercise.options ?? []).slice(0, 30).map((value) => cleanText(value, 250)),
      pairs: (exercise.pairs ?? []).slice(0, 30).map((pair) => ({
        left: cleanText(pair.left, 250),
        right: cleanText(pair.right, 250),
      })),
      paragraphParts: (exercise.paragraphParts ?? []).slice(0, 12).map((value) => cleanText(value, 500)),
      consequences: Object.fromEntries(Object.entries(exercise.consequences ?? {})
        .slice(0, 20)
        .map(([key, value]) => [cleanText(key, 250), cleanText(value, 500)])),
      visualStages: (exercise.visualStages ?? []).slice(0, 20).map((value) => cleanText(value, 500)),
      diagramParts: (exercise.diagramParts ?? []).slice(0, 30).map((part) => ({
        id: cleanText(part.id, 100),
        label: cleanText(part.label, 250),
        x: Number(part.x) || 0,
        y: Number(part.y) || 0,
      })),
      correctLabels: Object.fromEntries(Object.entries(exercise.correctLabels ?? {})
        .slice(0, 30)
        .map(([key, value]) => [cleanText(key, 100), cleanText(value, 250)])),
      correctOrder: (exercise.correctOrder ?? []).slice(0, 30).map((value) => cleanText(value, 250)),
      categories: (exercise.categories ?? []).slice(0, 12).map((value) => cleanText(value, 150)),
      correctAnswers: [...(exercise.correctAnswers ?? [])].slice(0, 20).map((value) => cleanText(value, 250)),
      explanation: cleanText(exercise.explanation, 1200),
      submittedAnswer: cleanText(studentAnswer, 2000),
      answerSubmitted: answerSubmitted === true,
      answerCorrect: typeof answerCorrect === 'boolean' ? answerCorrect : null,
    };
  }

  return {
    preferredLanguage: ['en', 'fr', 'es', 'hi', 'ru'].includes(preferredLanguage)
      ? preferredLanguage
      : 'en',
    topic: {
      id: topic.id,
      title: cleanText(topic.question, 180),
      description: cleanText(topic.content, 1200),
      publishedLessons: lessons.length,
      completedLessons,
      completionStatus: completedLessons >= lessons.length ? 'complete' : completedLessons > 0 ? 'in progress' : 'not started',
    },
    lesson: {
      id: lessonId,
      title: cleanText(lesson.question, 180) || cleanText(topic.question, 180),
      sequence: lessonNumber,
      publishedLessonsInTopic: lessons.length,
      content: cleanText(lesson.content, 4000),
      completed: completedForCurrentTopic.has(lessonId),
    },
    activeExercise,
    completedTopics,
  };
}

export function formatBoboContext(context) {
  return `<lesson_context>\n${JSON.stringify(context)}\n</lesson_context>`;
}
