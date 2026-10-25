import {buildBoboLessonContext, formatBoboContext} from './bobo_context.js';
import {BOBO_PROMPT_VERSION, BOBO_SYSTEM_PROMPT} from './bobo_prompt.js';

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

  const history = Array.isArray(body.history) ? body.history.slice(-MAX_HISTORY_MESSAGES) : [];
  const messages = history.map((item) => {
    if (!item || !['user', 'assistant'].includes(item.role) || typeof item.content !== 'string') {
      throw new BoboError('invalid_history', 400);
    }
    const content = item.content.trim();
    if (!content || content.length > MAX_MESSAGE_CHARS) throw new BoboError('invalid_history', 400);
    return {role: item.role, content};
  });

  const exerciseIndex = body.exerciseIndex === null || body.exerciseIndex === undefined
    ? null
    : Number(body.exerciseIndex);
  if (exerciseIndex !== null && !Number.isInteger(exerciseIndex)) {
    throw new BoboError('invalid_context', 400);
  }
  const studentAnswer = typeof body.studentAnswer === 'string'
    ? body.studentAnswer.slice(0, 2000)
    : '';

  return {
    message,
    topicId,
    lessonId,
    exerciseIndex,
    studentAnswer,
    answerSubmitted: body.answerSubmitted === true,
    answerCorrect: typeof body.answerCorrect === 'boolean' ? body.answerCorrect : null,
    history: messages,
  };
}

function estimateTokens(text) {
  return Math.ceil(text.length / 3.5);
}

function outputText(responseBody) {
  if (typeof responseBody.output_text === 'string') return responseBody.output_text.trim();
  const parts = (responseBody.output ?? []).flatMap((item) => item.content ?? [])
    .filter((item) => item.type === 'output_text' && typeof item.text === 'string')
    .map((item) => item.text);
  return parts.join('\n').trim();
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
    async reply(accountId, body) {
      if (!enabled) throw new BoboError('disabled', 503);
      if (!apiKey) throw new BoboError('not_configured', 503);
      const request = validateRequest(body);
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
          topicId: request.topicId,
          lessonId: request.lessonId,
          exerciseIndex: request.exerciseIndex,
          studentAnswer: request.studentAnswer,
          answerSubmitted: request.answerSubmitted,
          answerCorrect: request.answerCorrect,
          preferredLanguage,
          progressRows: progressResult.rows,
        });
      } catch (error) {
        if (error.status === 400 || error.status === 404) {
          throw new BoboError('invalid_context', 400);
        }
        throw error;
      }
      const contextInput = formatBoboContext(context);
      const input = [
        {role: 'user', content: contextInput},
        ...request.history,
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
            instructions: BOBO_SYSTEM_PROMPT,
            input,
            max_output_tokens: MAX_OUTPUT_TOKENS,
            reasoning: {effort: 'low'},
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
      const replyText = outputText(result);
      if (!replyText || replyText.length > 5000) throw new BoboError('empty_reply', 502);

      const usage = result.usage ?? {};
      const inputTokens = Number(usage.input_tokens) || 0;
      const outputTokens = Number(usage.output_tokens) || 0;
      pool.query(
        `UPDATE bobo_daily_usage
         SET input_tokens = input_tokens + $2,
             output_tokens = output_tokens + $3,
             updated_at = now()
         WHERE account_id = $1 AND usage_date = (now() AT TIME ZONE 'UTC')::date`,
        [accountId, inputTokens, outputTokens],
      ).catch((error) => console.error('Could not record Bobo token usage:', error.message));

      return {
        reply: replyText,
        remainingToday: Math.max(0, dailyRequestLimit - usageReservation.rows[0].request_count),
        usage: {inputTokens, outputTokens},
        promptVersion: BOBO_PROMPT_VERSION,
      };
    },
  };
}
