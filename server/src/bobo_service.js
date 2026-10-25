import {buildBoboLessonContext, formatBoboContext} from './bobo_context.js';
import {BOBO_PROMPT_VERSION, BOBO_SYSTEM_PROMPT} from './bobo_prompt.js';
import {createTutoringPlan, TEACHING_ACTIONS, tutorStateForStorage, tutoringDirective, validateTutorOutput} from './bobo_tutoring.js';

const MAX_MESSAGE_CHARS = 1200;
const MAX_HISTORY_MESSAGES = 10;
const MAX_OUTPUT_TOKENS = 280;
const REQUEST_TIMEOUT_MS = 25000;

export class BoboError extends Error {
  constructor(code, status) {
    super(code);
    this.code = code;
    this.status = status;
  }
}

function validateRequest(body) {
  const message = typeof body.message === 'string' ? body.message.trim() : '';
  if (!message || message.length > MAX_MESSAGE_CHARS) {
    throw new BoboError('invalid_message', 400);
  }
  const topicId = typeof body.topicId === 'string' ? body.topicId.trim() : '';
  const lessonId = typeof body.lessonId === 'string' ? body.lessonId.trim() : '';
  if (!topicId || topicId.length > 120 || !lessonId || lessonId.length > 40) {
    throw new BoboError('invalid_context', 400);
  }

  const exerciseIndex = body.exerciseIndex === null || body.exerciseIndex === undefined
    ? null
    : Number(body.exerciseIndex);
  if (exerciseIndex !== null && !Number.isInteger(exerciseIndex)) {
    throw new BoboError('invalid_context', 400);
  }
  const teachingAction = body.teachingAction == null ? null : String(body.teachingAction);
  if (teachingAction !== null && !TEACHING_ACTIONS.has(teachingAction)) {
    throw new BoboError('invalid_teaching_action', 400);
  }

  return {
    message,
    topicId,
    lessonId,
    exerciseIndex,
    teachingAction,
  };
}

function estimateTokens(text) {
  return Math.ceil(text.length / 3.5);
}

function normalizeAnswer(value) {
  return String(value).trim().toLowerCase().replace(/\s+/g, ' ');
}

function gradeAnswer(exercise, answer) {
  const normalizeList = (values) => values.map(normalizeAnswer).sort();
  const correctAnswers = exercise.correctAnswers ?? [];
  const correctOrder = exercise.correctOrder ?? [];
  const pairs = exercise.pairs ?? [];
  const supplied = normalizeAnswer(answer);
  if (!supplied) return {submitted: false, correct: null};
  switch (exercise.type) {
    case 'multipleSelect': {
      const selected = answer.split(',').map(normalizeAnswer).filter(Boolean);
      return {submitted: true, correct: JSON.stringify(normalizeList(selected)) === JSON.stringify(normalizeList(correctAnswers))};
    }
    case 'fillInTheBlank': {
      const selected = answer.split('|').map(normalizeAnswer);
      return {submitted: true, correct: JSON.stringify(selected) === JSON.stringify(correctOrder.map(normalizeAnswer))};
    }
    case 'orderSteps':
    case 'buildTheProcess': {
      const selected = answer.split(/\s*\u2192\s*/u).map(normalizeAnswer);
      return {submitted: true, correct: JSON.stringify(selected) === JSON.stringify(correctOrder.map(normalizeAnswer))};
    }
    case 'matching':
    case 'categorization':
    case 'causeAndEffect':
    case 'compareAndContrast': {
      const selected = new Map(answer.split(';').map((entry) => {
        const separator = entry.indexOf(':');
        return separator < 0
          ? ['', '']
          : [normalizeAnswer(entry.slice(0, separator)), normalizeAnswer(entry.slice(separator + 1))];
      }));
      return {
        submitted: true,
        correct: pairs.length > 0 && pairs.every((pair) =>
          selected.get(normalizeAnswer(pair.left)) === normalizeAnswer(pair.right)),
      };
    }
    case 'diagramLabeling': {
      const labels = exercise.correctLabels ?? {};
      const selected = new Map(answer.split(';').map((entry) => {
        const separator = entry.indexOf(':');
        return separator < 0
          ? ['', '']
          : [entry.slice(0, separator).trim(), normalizeAnswer(entry.slice(separator + 1))];
      }));
      const required = Object.entries(labels);
      return {
        submitted: true,
        correct: required.length > 0 && required.every(([id, label]) =>
          selected.get(id) === normalizeAnswer(label)),
      };
    }
    case 'singleChoice':
    case 'trueFalse':
    case 'spotTheMistake':
      return {submitted: true, correct: correctAnswers.some((value) => normalizeAnswer(value) === supplied)};
    case 'shortAnswer':
    case 'scenarioBasedDecision':
    case 'prediction':
      return {submitted: true, correct: correctAnswers.length
        ? correctAnswers.some((value) => normalizeAnswer(value) === supplied)
        : null};
    default:
      return {submitted: true, correct: null};
  }
}

function isCompleteAttempt(exercise, answer) {
  if (typeof answer !== 'string' || !answer.trim()) return false;
  const options = (exercise.options ?? []).map(normalizeAnswer);
  const correctOrder = exercise.correctOrder ?? [];
  const splitSequence = () => answer.split(/\s*\u2192\s*/u).map((part) => part.trim());
  switch (exercise.type) {
    case 'singleChoice':
    case 'trueFalse':
    case 'spotTheMistake':
    case 'scenarioBasedDecision':
    case 'prediction':
      return options.includes(normalizeAnswer(answer));
    case 'multipleSelect': {
      const selected = answer.split(',').map(normalizeAnswer).filter(Boolean);
      return selected.length > 0 && selected.every((item) => options.includes(item));
    }
    case 'shortAnswer':
      return answer.trim().length <= 2000;
    case 'fillInTheBlank': {
      const words = answer.split('|').map((part) => part.trim());
      return words.length === correctOrder.length && words.every(Boolean);
    }
    case 'orderSteps':
    case 'buildTheProcess': {
      const steps = splitSequence();
      return steps.length === correctOrder.length && steps.every(Boolean) &&
        (options.length === 0 || steps.every((step) => options.includes(normalizeAnswer(step))));
    }
    case 'matching':
    case 'categorization':
    case 'causeAndEffect':
    case 'compareAndContrast': {
      const selected = new Map(answer.split(';').map((entry) => {
        const separator = entry.indexOf(':');
        return separator < 0 ? ['', ''] : [entry.slice(0, separator).trim(), entry.slice(separator + 1).trim()];
      }));
      const expected = (exercise.pairs ?? []).map((pair) => pair.left);
      return expected.length > 0 && selected.size === expected.length &&
        expected.every((key) => selected.has(key) && Boolean(selected.get(key)));
    }
    default:
      return false;
  }
}

function validLessonRequest(body) {
  const topicId = typeof body.topicId === 'string' ? body.topicId.trim() : '';
  const lessonId = typeof body.lessonId === 'string' ? body.lessonId.trim() : '';
  const exerciseIndex = body.exerciseIndex;
  if (!topicId || topicId.length > 120 || !/^lesson-\d{1,2}$/.test(lessonId) ||
      !Number.isInteger(exerciseIndex) || exerciseIndex < 0) {
    throw new BoboError('invalid_context', 400);
  }
  return {topicId, lessonId, exerciseIndex};
}

function outputText(responseBody) {
  if (typeof responseBody.output_text === 'string') return responseBody.output_text.trim();
  const parts = (responseBody.output ?? []).flatMap((item) => item.content ?? [])
    .filter((item) => item.type === 'output_text' && typeof item.text === 'string')
    .map((item) => item.text);
  return parts.join('\n').trim();
}

function validId(value) {
  return typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

export function createBoboTutor({
  pool,
  getLessonContent,
  apiKey = process.env.OPENAI_API_KEY ?? '',
  model = process.env.OPENAI_MODEL ?? 'gpt-5.6-luna',
  enabled = String(process.env.BOBO_ENABLED ?? 'false').toLowerCase() === 'true',
  dailyRequestLimit = Number(process.env.BOBO_DAILY_REQUEST_LIMIT ?? 20),
  dailyTokenLimit = Number(process.env.BOBO_DAILY_TOKEN_BUDGET ?? 30000),
  fetchImpl = globalThis.fetch,
}) {
  return {
    async recordAttempt(accountId, body) {
      const {topicId, lessonId, exerciseIndex} = validLessonRequest(body);
      const answer = typeof body.studentAnswer === 'string' ? body.studentAnswer.trim() : '';
      if (!answer || answer.length > 2000) throw new BoboError('invalid_answer', 400);
      const accountResult = await pool.query(
        'SELECT preferred_language FROM accounts WHERE id = $1',
        [accountId],
      );
      if (!accountResult.rowCount) throw new BoboError('unauthorized', 401);
      let context;
      try {
        context = buildBoboLessonContext({
          content: getLessonContent(accountResult.rows[0].preferred_language ?? 'en'),
          topicId,
          lessonId,
          exerciseIndex,
          studentAnswer: answer,
          answerSubmitted: false,
          answerCorrect: null,
          preferredLanguage: accountResult.rows[0].preferred_language ?? 'en',
          progressRows: [],
        });
      } catch (error) {
        if (error.status === 400 || error.status === 404) throw new BoboError('invalid_context', 400);
        throw error;
      }
      if (!context.activeExercise || !isCompleteAttempt(context.activeExercise, answer)) {
        throw new BoboError('invalid_answer', 400);
      }
      const result = gradeAnswer(context.activeExercise, answer);
      if (!result.submitted) throw new BoboError('invalid_answer', 400);
      await pool.query(
        `INSERT INTO bobo_exercise_tutoring_state
           (account_id, topic_id, lesson_id, exercise_index, student_answer,
            answer_correct, attempt_count, attempted_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, 1, now(), now())
         ON CONFLICT (account_id, topic_id, lesson_id, exercise_index)
         DO UPDATE SET student_answer = EXCLUDED.student_answer,
           answer_correct = EXCLUDED.answer_correct,
           attempt_count = bobo_exercise_tutoring_state.attempt_count + 1,
           attempted_at = now(), updated_at = now()`,
        [accountId, topicId, lessonId, exerciseIndex, answer, result.correct],
      );
      return {recorded: true};
    },

    async getAttemptedExercises(accountId, body) {
      const topicId = typeof body.topicId === 'string' ? body.topicId.trim() : '';
      const lessonId = typeof body.lessonId === 'string' ? body.lessonId.trim() : '';
      if (!topicId || topicId.length > 120 || !/^lesson-\d{1,2}$/.test(lessonId)) {
        throw new BoboError('invalid_context', 400);
      }
      const result = await pool.query(
        `SELECT exercise_index, answer_correct FROM bobo_exercise_tutoring_state
         WHERE account_id = $1 AND topic_id = $2 AND lesson_id = $3
           AND attempted_at IS NOT NULL ORDER BY exercise_index`,
        [accountId, topicId, lessonId],
      );
      return {attemptedExercises: result.rows.map((row) => ({
        exerciseIndex: Number(row.exercise_index),
        correct: typeof row.answer_correct === 'boolean' ? row.answer_correct : null,
      }))};
    },

    async openConversation(accountId, body) {
      const topicId = typeof body.topicId === 'string' ? body.topicId.trim() : '';
      const lessonId = typeof body.lessonId === 'string' ? body.lessonId.trim() : '';
      if (!topicId || topicId.length > 120 || !lessonId || lessonId.length > 40) {
        throw new BoboError('invalid_context', 400);
      }
      const accountResult = await pool.query(
        'SELECT preferred_language FROM accounts WHERE id = $1',
        [accountId],
      );
      if (!accountResult.rowCount) throw new BoboError('unauthorized', 401);
      const preferredLanguage = accountResult.rows[0].preferred_language ?? 'en';
      const content = getLessonContent(preferredLanguage);
      try {
        buildBoboLessonContext({
          content,
          topicId,
          lessonId,
          exerciseIndex: null,
          preferredLanguage,
          progressRows: [],
        });
      } catch (error) {
        if (error.status === 400 || error.status === 404) {
          throw new BoboError('invalid_context', 400);
        }
        throw error;
      }
      const conversation = await pool.query(
        `INSERT INTO bobo_conversations (account_id, topic_id, lesson_id)
         VALUES ($1, $2, $3)
         ON CONFLICT (account_id, topic_id, lesson_id)
         DO UPDATE SET updated_at = now()
         RETURNING id, topic_id, lesson_id, created_at, updated_at`,
        [accountId, topicId, lessonId],
      );
      const row = conversation.rows[0];
      const messages = await pool.query(
        `SELECT id, role, content, exercise_index, created_at
         FROM (
           SELECT id, role, content, exercise_index, created_at
           FROM bobo_messages WHERE conversation_id = $1
           ORDER BY created_at DESC, id DESC LIMIT 50
         ) recent ORDER BY created_at, id`,
        [row.id],
      );
      return {
        conversation: {
          id: row.id,
          topicId: row.topic_id,
          lessonId: row.lesson_id,
          createdAt: row.created_at,
          updatedAt: row.updated_at,
        },
        messages: messages.rows.map((message) => ({
          id: message.id,
          role: message.role,
          content: message.content,
          exerciseIndex: message.exercise_index,
          createdAt: message.created_at,
        })),
      };
    },

    async deleteConversation(accountId, conversationId) {
      if (!validId(conversationId)) throw new BoboError('invalid_context', 400);
      const result = await pool.query(
        'DELETE FROM bobo_conversations WHERE id = $1 AND account_id = $2 RETURNING id',
        [conversationId, accountId],
      );
      if (!result.rowCount) throw new BoboError('conversation_not_found', 404);
      return {deleted: true};
    },

    async reply(accountId, conversationId, body) {
      if (!enabled) throw new BoboError('disabled', 503);
      if (!apiKey) throw new BoboError('not_configured', 503);
      if (!validId(conversationId)) throw new BoboError('invalid_context', 400);
      const request = validateRequest(body);
      const conversationResult = await pool.query(
        `SELECT topic_id, lesson_id FROM bobo_conversations
         WHERE id = $1 AND account_id = $2`,
        [conversationId, accountId],
      );
      if (!conversationResult.rowCount) throw new BoboError('conversation_not_found', 404);
      const conversation = conversationResult.rows[0];
      const requestTopicId = typeof body.topicId === 'string' ? body.topicId.trim() : conversation.topic_id;
      const requestLessonId = typeof body.lessonId === 'string' ? body.lessonId.trim() : conversation.lesson_id;
      if (requestTopicId !== conversation.topic_id || requestLessonId !== conversation.lesson_id) {
        throw new BoboError('invalid_context', 400);
      }
      const accountResult = await pool.query(
        'SELECT preferred_language FROM accounts WHERE id = $1',
        [accountId],
      );
      if (!accountResult.rowCount) throw new BoboError('unauthorized', 401);
      const preferredLanguage = accountResult.rows[0].preferred_language ?? 'en';
      const content = getLessonContent(preferredLanguage);
      const progressResult = await pool.query(
        `SELECT topic_id, array_agg(lesson_id ORDER BY lesson_id) AS lesson_ids
         FROM lesson_progress WHERE account_id = $1 GROUP BY topic_id`,
        [accountId],
      );
      let context;
      try {
        context = buildBoboLessonContext({
          content,
          topicId: conversation.topic_id,
          lessonId: conversation.lesson_id,
          exerciseIndex: request.exerciseIndex,
          studentAnswer: '',
          answerSubmitted: false,
          answerCorrect: null,
          preferredLanguage,
          progressRows: progressResult.rows,
        });
      } catch (error) {
        if (error.status === 400 || error.status === 404) {
          throw new BoboError('invalid_context', 400);
        }
        throw error;
      }
      let exerciseState = null;
      if (context.activeExercise) {
        const stateResult = await pool.query(
          `SELECT student_answer, answer_correct, attempted_at, hint_level,
                  tutoring_mode, tutoring_state
           FROM bobo_exercise_tutoring_state
           WHERE account_id = $1 AND topic_id = $2 AND lesson_id = $3 AND exercise_index = $4`,
          [accountId, conversation.topic_id, conversation.lesson_id, request.exerciseIndex],
        );
        exerciseState = stateResult.rows[0] ?? null;
        const hasAttempt = Boolean(exerciseState?.attempted_at);
        if (!hasAttempt && request.teachingAction !== 'giveHint') {
          throw new BoboError('attempt_required', 403);
        }
        context.activeExercise.submittedAnswer = hasAttempt ? exerciseState.student_answer : '';
        context.activeExercise.answerSubmitted = hasAttempt;
        context.activeExercise.answerCorrect = hasAttempt ? exerciseState.answer_correct : null;
      } else {
        const priorAttempt = await pool.query(
          `SELECT count(*)::integer AS attempted_count FROM bobo_exercise_tutoring_state
           WHERE account_id = $1 AND topic_id = $2 AND lesson_id = $3
             AND attempted_at IS NOT NULL`,
          [accountId, conversation.topic_id, conversation.lesson_id],
        );
        if (Number(priorAttempt.rows[0]?.attempted_count ?? 0) < context.lesson.exerciseCount) {
          throw new BoboError('attempt_required', 403);
        }
      }
      const plan = createTutoringPlan({
        exerciseKey: context.activeExercise ? `${conversation.lesson_id}:${request.exerciseIndex}` : null,
        answerSubmitted: context.activeExercise?.answerSubmitted ?? false,
        answerCorrect: context.activeExercise?.answerCorrect ?? null,
        previousState: exerciseState ? {
          exerciseKey: `${conversation.lesson_id}:${request.exerciseIndex}`,
          hintLevel: Number(exerciseState.hint_level) || 0,
          state: exerciseState.tutoring_state,
        } : {},
        action: request.teachingAction,
      });
      context.tutoringPlan = {
        mode: plan.mode,
        state: plan.state,
        hintLevel: plan.hintLevel,
        previousState: plan.previousState,
        allowDirectAnswer: plan.allowDirectAnswer,
        action: plan.action,
      };
      const contextInput = formatBoboContext(context);
      const historyResult = await pool.query(
        `SELECT role, content FROM (
           SELECT role, content, exercise_index, created_at, id FROM bobo_messages
           WHERE conversation_id = $1 ORDER BY created_at DESC, id DESC LIMIT $2
         ) recent ORDER BY created_at, id`,
        [conversationId, MAX_HISTORY_MESSAGES],
      );
      const input = [
        {role: 'user', content: contextInput},
        ...historyResult.rows.map(({role, content: text, exercise_index: oldExerciseIndex}) => ({
          role,
          content: oldExerciseIndex === request.exerciseIndex
            ? text
            : `[Earlier in this lesson${oldExerciseIndex === null ? '' : `, exercise ${oldExerciseIndex + 1}`}]: ${text}`,
        })),
        {role: 'user', content: request.message},
      ];
      const reservedTokens = estimateTokens(`${BOBO_SYSTEM_PROMPT}${JSON.stringify(input)}`) + MAX_OUTPUT_TOKENS;
      const usageReservation = await pool.query(
        `INSERT INTO bobo_daily_usage (account_id, usage_date, request_count, estimated_tokens)
         VALUES ($1, (now() AT TIME ZONE 'UTC')::date, 1, $2)
         ON CONFLICT (account_id, usage_date) DO UPDATE
           SET request_count = bobo_daily_usage.request_count + 1,
               estimated_tokens = bobo_daily_usage.estimated_tokens + $2,
               updated_at = now()
           WHERE bobo_daily_usage.request_count < $3
             AND bobo_daily_usage.estimated_tokens + $2 <= $4
         RETURNING request_count`,
        [accountId, reservedTokens, dailyRequestLimit, dailyTokenLimit],
      );
      if (!usageReservation.rowCount) throw new BoboError('daily_limit', 429);

      let providerResponse;
      try {
        providerResponse = await fetchImpl('https://api.openai.com/v1/responses', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${apiKey}`,
            'Content-Type': 'application/json',
          },
          signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
          body: JSON.stringify({
            model,
            instructions: `${BOBO_SYSTEM_PROMPT}\n\nServer-selected tutoring strategy: ${tutoringDirective(plan)}`,
            input,
            max_output_tokens: MAX_OUTPUT_TOKENS,
            reasoning: {effort: 'low'},
            text: {format: {
              type: 'json_schema',
              name: 'bobo_tutor_reply',
              strict: true,
              schema: {
                type: 'object',
                properties: {
                  message: {type: 'string'},
                  teachingMode: {type: 'string', enum: ['socratic', 'progressiveHint', 'conceptExplanation', 'misconceptionCorrection', 'deeperExploration', 'example', 'quiz']},
                  tutoringState: {type: 'string', enum: ['diagnosing', 'guiding', 'hinting', 'correctingMisconception', 'explaining', 'checkingUnderstanding', 'completed']},
                  hintLevel: {type: 'integer', minimum: 0, maximum: 4},
                  misconceptionDetected: {type: 'boolean'},
                  understandingDemonstrated: {type: 'boolean'},
                  shouldReturnToExercise: {type: 'boolean'},
                  directExplanationRequested: {type: 'boolean'},
                },
                required: ['message', 'teachingMode', 'tutoringState', 'hintLevel', 'misconceptionDetected', 'understandingDemonstrated', 'shouldReturnToExercise', 'directExplanationRequested'],
                additionalProperties: false,
              },
            }},
            store: false,
          }),
        });
      } catch (error) {
        console.error('Bobo provider request failed:', error.name === 'TimeoutError' ? 'timeout' : 'network error');
        throw new BoboError(error.name === 'TimeoutError' ? 'timeout' : 'unavailable', 502);
      }
      if (!providerResponse.ok) {
        console.error(`Bobo provider returned HTTP ${providerResponse.status}.`);
        throw new BoboError('unavailable', 502);
      }

      let result;
      try {
        result = await providerResponse.json();
      } catch (_error) {
        throw new BoboError('unavailable', 502);
      }
      const rawOutput = outputText(result);
      if (!rawOutput || rawOutput.length > 5000) throw new BoboError('empty_reply', 502);
      let parsedOutput;
      try {
        parsedOutput = JSON.parse(rawOutput);
      } catch (_error) {
        throw new BoboError('invalid_model_response', 502);
      }
      const validatedOutput = validateTutorOutput(parsedOutput, plan);
      if (!validatedOutput) throw new BoboError('invalid_model_response', 502);
      const replyText = validatedOutput.message;
      const storedTutorState = tutorStateForStorage(validatedOutput, plan);

      const usage = result.usage ?? {};
      const inputTokens = Number(usage.input_tokens) || 0;
      const outputTokens = Number(usage.output_tokens) || 0;
      const db = await pool.connect();
      try {
        await db.query('BEGIN');
        await db.query(
          `INSERT INTO bobo_messages
             (conversation_id, role, content, exercise_index, input_tokens, output_tokens)
           VALUES ($1, 'user', $2, $3, 0, 0), ($1, 'assistant', $4, $3, $5, $6)`,
          [conversationId, request.message, request.exerciseIndex, replyText, inputTokens, outputTokens],
        );
        if (request.exerciseIndex !== null) {
          await db.query(
            `INSERT INTO bobo_exercise_tutoring_state
               (account_id, topic_id, lesson_id, exercise_index, hint_level,
                tutoring_mode, tutoring_state, updated_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7, now())
             ON CONFLICT (account_id, topic_id, lesson_id, exercise_index)
             DO UPDATE SET hint_level = EXCLUDED.hint_level,
               tutoring_mode = EXCLUDED.tutoring_mode,
               tutoring_state = EXCLUDED.tutoring_state,
               updated_at = now()`,
            [accountId, conversation.topic_id, conversation.lesson_id, request.exerciseIndex,
              storedTutorState.hintLevel, storedTutorState.mode, storedTutorState.state],
          );
        }
        await db.query(
          `UPDATE bobo_conversations SET updated_at = now()
           WHERE id = $1 AND account_id = $2`,
          [conversationId, accountId],
        );
        await db.query(
          `UPDATE bobo_daily_usage
           SET input_tokens = input_tokens + $2,
               output_tokens = output_tokens + $3,
               updated_at = now()
           WHERE account_id = $1 AND usage_date = (now() AT TIME ZONE 'UTC')::date`,
          [accountId, inputTokens, outputTokens],
        );
        await db.query(
          `DELETE FROM bobo_messages
           WHERE conversation_id = $1 AND id NOT IN (
             SELECT id FROM bobo_messages WHERE conversation_id = $1
             ORDER BY created_at DESC, id DESC LIMIT 200
           )`,
          [conversationId],
        );
        await db.query('COMMIT');
      } catch (error) {
        await db.query('ROLLBACK');
        console.error('Could not store Bobo conversation reply:', error.message);
        throw new BoboError('unavailable', 500);
      } finally {
        db.release();
      }

      return {
        reply: replyText,
        remainingToday: Math.max(0, dailyRequestLimit - usageReservation.rows[0].request_count),
        usage: {inputTokens, outputTokens},
        promptVersion: BOBO_PROMPT_VERSION,
      };
    },
  };
}
