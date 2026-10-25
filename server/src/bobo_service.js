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
  const studentAnswer = typeof body.studentAnswer === 'string'
    ? body.studentAnswer.slice(0, 2000)
    : '';
  const answerSubmitted = body.answerSubmitted === true;
  const teachingAction = body.teachingAction == null ? null : String(body.teachingAction);
  if (teachingAction !== null && !TEACHING_ACTIONS.has(teachingAction)) {
    throw new BoboError('invalid_teaching_action', 400);
  }

  return {
    message,
    topicId,
    lessonId,
    exerciseIndex,
    studentAnswer,
    answerSubmitted,
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
      const selected = answer.split(/\s*→\s*/).map(normalizeAnswer);
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
        `SELECT topic_id, lesson_id, tutoring_state FROM bobo_conversations
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
          studentAnswer: request.studentAnswer,
          answerSubmitted: request.answerSubmitted,
          answerCorrect: null,
          preferredLanguage,
          progressRows: progressResult.rows,
        });
        if (context.activeExercise && request.answerSubmitted) {
          const answerStatus = gradeAnswer(context.activeExercise, request.studentAnswer);
          context.activeExercise.answerSubmitted = answerStatus.submitted;
          context.activeExercise.answerCorrect = answerStatus.correct;
        } else if (context.activeExercise) {
          context.activeExercise.answerSubmitted = false;
          context.activeExercise.answerCorrect = null;
        }
      } catch (error) {
        if (error.status === 400 || error.status === 404) {
          throw new BoboError('invalid_context', 400);
        }
        throw error;
      }
      const plan = createTutoringPlan({
        exerciseKey: context.activeExercise ? `${conversation.lesson_id}:${request.exerciseIndex}` : null,
        answerSubmitted: context.activeExercise?.answerSubmitted ?? false,
        answerCorrect: context.activeExercise?.answerCorrect ?? null,
        previousState: conversation.tutoring_state ?? {},
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
        await db.query(
          `UPDATE bobo_conversations SET tutoring_state = $3::jsonb, updated_at = now()
           WHERE id = $1 AND account_id = $2`,
          [conversationId, accountId, JSON.stringify(storedTutorState)],
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
