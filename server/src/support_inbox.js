import {createHmac, timingSafeEqual} from 'node:crypto';
import sanitizeHtml from 'sanitize-html';

export const SUPPORT_INBOXES = [
  'hello@howbuddy.app',
  'support@howbuddy.app',
  'contact@howbuddy.app',
];

const safeHtmlOptions = {
  allowedTags: [
    'a', 'b', 'blockquote', 'br', 'code', 'div', 'em', 'h1', 'h2', 'h3',
    'hr', 'i', 'li', 'ol', 'p', 'pre', 'span', 'strong', 'table', 'tbody',
    'td', 'th', 'thead', 'tr', 'ul',
  ],
  allowedAttributes: {a: ['href', 'title'], td: ['colspan', 'rowspan'], th: ['colspan', 'rowspan']},
  allowedSchemes: ['http', 'https', 'mailto'],
  disallowedTagsMode: 'discard',
};

export function sanitizeEmailHtml(value) {
  return sanitizeHtml(String(value ?? ''), safeHtmlOptions);
}

export function verifyResendWebhook(rawBody, headers, secret, now = Date.now()) {
  const id = String(headers['svix-id'] ?? '');
  const timestamp = String(headers['svix-timestamp'] ?? '');
  const signatures = String(headers['svix-signature'] ?? '');
  if (!id || !timestamp || !signatures || !secret) return false;
  const seconds = Number(timestamp);
  if (!Number.isFinite(seconds) || Math.abs(now / 1000 - seconds) > 300) return false;
  let key;
  try {
    key = Buffer.from(secret.replace(/^whsec_/, ''), 'base64');
  } catch (_error) {
    return false;
  }
  const expected = createHmac('sha256', key)
    .update(`${id}.${timestamp}.${rawBody.toString('utf8')}`)
    .digest('base64');
  return signatures.split(' ').some((item) => {
    const [version, candidate] = item.split(',', 2);
    if (version !== 'v1' || !candidate) return false;
    const left = Buffer.from(candidate);
    const right = Buffer.from(expected);
    return left.length === right.length && timingSafeEqual(left, right);
  });
}

export function createSupportInbox({pool, apiKey = '', fetchImpl = fetch, logger = console}) {
  async function resend(path, options = {}) {
    if (!apiKey) throw new Error('Resend is not configured.');
    const response = await fetchImpl(`https://api.resend.com${path}`, {
      ...options,
      headers: {
        Authorization: `Bearer ${apiKey}`,
        ...(options.body ? {'Content-Type': 'application/json'} : {}),
        ...options.headers,
      },
      signal: AbortSignal.timeout(20_000),
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(`Resend request failed (${response.status}).`);
    return payload;
  }

  async function receive(emailId) {
    if (!emailId || emailId.length > 200) throw new Error('Invalid inbound email id.');
    const stored = await pool.query(
      'SELECT id FROM support_messages WHERE provider_email_id = $1', [emailId],
    );
    if (stored.rowCount) return {duplicate: true};

    const email = await resend(`/emails/receiving/${encodeURIComponent(emailId)}`);
    const recipients = normalizeAddresses(email.to);
    const inbox = recipients.find((address) => SUPPORT_INBOXES.includes(address));
    if (!inbox) return {ignored: true};
    const sender = normalizeAddress(email.from);
    if (!sender) return {ignored: true};
    const headers = lowerCaseHeaders(email.headers);
    const messageId = String(email.message_id ?? headers['message-id'] ?? '').trim();
    const inReplyTo = String(email.in_reply_to ?? headers['in-reply-to'] ?? '').trim();
    const references = parseReferences(email.references ?? headers.references ?? '');
    const subject = String(email.subject ?? '').slice(0, 998);
    const textBody = String(email.text ?? email.text_body ?? '').slice(0, 1_000_000);
    const htmlBody = sanitizeEmailHtml(email.html ?? email.html_body ?? '').slice(0, 1_000_000);
    const receivedAt = validDate(email.created_at ?? email.received_at);
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query('SELECT pg_advisory_xact_lock(hashtextextended($1, 0))', [emailId]);
      const duplicate = await client.query(
        'SELECT id FROM support_messages WHERE provider_email_id = $1 FOR UPDATE', [emailId],
      );
      if (duplicate.rowCount) {
        await client.query('ROLLBACK');
        return {duplicate: true};
      }
      const relatedIds = [...new Set([inReplyTo, ...references].filter(Boolean))];
      let conversation = null;
      if (relatedIds.length) {
        const linked = await client.query(
          `SELECT c.id FROM support_messages m
           JOIN support_conversations c ON c.id = m.conversation_id
           WHERE c.inbox_address = $1 AND m.message_id = ANY($2::text[])
           ORDER BY m.received_at DESC LIMIT 1`, [inbox, relatedIds],
        );
        conversation = linked.rows[0] ?? null;
      }
      if (!conversation) {
        const created = await client.query(
          `INSERT INTO support_conversations (inbox_address, sender_email, subject, is_read, last_activity_at)
           VALUES ($1, $2, $3, false, $4) RETURNING id`, [inbox, sender, subject, receivedAt],
        );
        conversation = created.rows[0];
      } else {
        await client.query(
          'UPDATE support_conversations SET is_read = false, last_activity_at = $2 WHERE id = $1',
          [conversation.id, receivedAt],
        );
      }
      const inserted = await client.query(
        `INSERT INTO support_messages
         (conversation_id, direction, sender_email, recipient_email, subject, text_body, html_body,
          provider_email_id, message_id, in_reply_to, references_header, received_at)
         VALUES ($1, 'inbound', $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
         ON CONFLICT (provider_email_id) DO NOTHING RETURNING id`,
        [conversation.id, sender, inbox, subject, textBody, htmlBody, emailId, messageId,
          inReplyTo, references, receivedAt],
      );
      for (const attachment of (inserted.rows[0] ? (email.attachments ?? []) : [])) {
        const attachmentId = String(attachment.id ?? attachment.attachment_id ?? '');
        if (!attachmentId) continue;
        await client.query(
          `INSERT INTO support_attachments (message_id, provider_attachment_id, filename, content_type, size_bytes)
           VALUES ($1, $2, $3, $4, $5) ON CONFLICT DO NOTHING`,
          [inserted.rows[0]?.id, attachmentId,
            String(attachment.filename ?? 'attachment').slice(0, 255),
            String(attachment.content_type ?? attachment.contentType ?? 'application/octet-stream').slice(0, 255),
            Math.max(0, Number(attachment.size ?? 0))],
        );
      }
      await client.query('COMMIT');
      return {stored: Boolean(inserted.rowCount)};
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  return {
    async handleWebhook(event) {
      if (event.type !== 'email.received') return {ignored: true};
      const emailId = String(event.data?.email_id ?? event.data?.id ?? '');
      return receive(emailId);
    },

    async list({search = '', inbox = ''} = {}) {
      const values = [];
      const where = [];
      if (SUPPORT_INBOXES.includes(inbox)) {
        values.push(inbox);
        where.push(`c.inbox_address = $${values.length}`);
      }
      if (search.trim()) {
        values.push(`%${search.trim().slice(0, 200)}%`);
        where.push(`(c.sender_email ILIKE $${values.length} OR c.subject ILIKE $${values.length}
          OR EXISTS (SELECT 1 FROM support_messages sm WHERE sm.conversation_id = c.id
             AND (sm.text_body ILIKE $${values.length} OR sm.html_body ILIKE $${values.length})) )`);
      }
      const result = await pool.query(
        `SELECT c.id, c.inbox_address, c.sender_email, c.subject, c.is_read, c.last_activity_at,
          (SELECT count(*)::int FROM support_messages m WHERE m.conversation_id = c.id) AS message_count,
          (SELECT m.text_body FROM support_messages m WHERE m.conversation_id = c.id
            ORDER BY m.received_at DESC LIMIT 1) AS preview
         FROM support_conversations c ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
         ORDER BY c.last_activity_at DESC LIMIT 200`, values,
      );
      return result.rows;
    },

    async getConversation(id) {
      const result = await pool.query(
        `SELECT c.id, c.inbox_address, c.sender_email, c.subject, c.is_read, c.last_activity_at,
          COALESCE(json_agg(json_build_object(
            'id', m.id, 'direction', m.direction, 'senderEmail', m.sender_email,
            'recipientEmail', m.recipient_email, 'subject', m.subject,
            'text', m.text_body, 'html', m.html_body, 'messageId', m.message_id,
            'inReplyTo', m.in_reply_to, 'references', m.references_header,
            'receivedAt', m.received_at,
            'attachments', COALESCE((SELECT json_agg(json_build_object(
              'id', a.id, 'filename', a.filename, 'contentType', a.content_type, 'size', a.size_bytes
            )) FROM support_attachments a WHERE a.message_id = m.id), '[]'::json)
          ) ORDER BY m.received_at) FILTER (WHERE m.id IS NOT NULL), '[]'::json) AS messages
         FROM support_conversations c LEFT JOIN support_messages m ON m.conversation_id = c.id
         WHERE c.id = $1 GROUP BY c.id`, [id],
      );
      return result.rows[0] ?? null;
    },

    async markRead(id) {
      const result = await pool.query(
        'UPDATE support_conversations SET is_read = true WHERE id = $1 RETURNING id', [id],
      );
      return result.rowCount === 1;
    },

    async reply(id, text) {
      const body = String(text ?? '').trim();
      if (!body || body.length > 50_000) throw new Error('Write a reply under 50,000 characters.');
      const conversation = await this.getConversation(id);
      if (!conversation) throw new Error('Conversation not found.');
      if (!SUPPORT_INBOXES.includes(conversation.inbox_address)) throw new Error('Invalid support inbox.');
      if (!apiKey) throw new Error('Resend sending is not configured.');
      const messages = conversation.messages ?? [];
      const last = messages[messages.length - 1];
      const messageIds = [...new Set(messages.map((m) => m.messageId).filter(Boolean))];
      const references = [...new Set([...messageIds, ...(last?.references ?? [])])].slice(-50);
      const headers = {};
      if (last?.messageId) headers['In-Reply-To'] = last.messageId;
      if (references.length) headers.References = references.join(' ');
      const subject = conversation.subject.toLowerCase().startsWith('re:')
        ? conversation.subject
        : `Re: ${conversation.subject}`;
      const sent = await resend('/emails', {
        method: 'POST',
        body: JSON.stringify({
          from: `${conversation.inbox_address.split('@')[0]} <${conversation.inbox_address}>`,
          to: [conversation.sender_email], subject, text: body,
          html: `<p>${escapeHtml(body).replace(/\n/g, '<br>')}</p>`, headers,
        }),
      });
      const providerId = String(sent.id ?? '');
      if (!providerId) throw new Error('Resend did not return an email id.');
      let providerMessageId = '';
      try {
        const details = await resend(`/emails/${encodeURIComponent(providerId)}`);
        providerMessageId = String(details.message_id ?? details.headers?.['message-id'] ?? '');
      } catch (error) {
        logger.warn('Sent support reply; could not immediately retrieve Message-ID:', error.message);
      }
      await pool.query(
        `INSERT INTO support_messages
         (conversation_id, direction, sender_email, recipient_email, subject, text_body, provider_email_id,
          message_id, in_reply_to, references_header, received_at)
         VALUES ($1, 'outbound', $2, $3, $4, $5, $6, $7, $8, $9, now())`,
        [id, conversation.inbox_address, conversation.sender_email, subject, body, providerId,
          providerMessageId, last?.messageId ?? '', references],
      );
      await pool.query('UPDATE support_conversations SET last_activity_at = now() WHERE id = $1', [id]);
      return {sent: true};
    },

    async attachmentUrl(attachmentRecordId) {
      const result = await pool.query(
        `SELECT a.provider_attachment_id, m.provider_email_id
         FROM support_attachments a JOIN support_messages m ON m.id = a.message_id
         WHERE a.id = $1 AND m.direction = 'inbound'`, [attachmentRecordId],
      );
      const item = result.rows[0];
      if (!item) return null;
      const attachment = await resend(
        `/emails/receiving/${encodeURIComponent(item.provider_email_id)}/attachments/${encodeURIComponent(item.provider_attachment_id)}`,
      );
      const url = new URL(attachment.download_url);
      if (url.protocol !== 'https:') throw new Error('Unsafe attachment download URL.');
      return {url: url.toString(), expiresAt: attachment.expires_at};
    },
  };
}

function normalizeAddress(value) {
  const values = normalizeAddresses(value);
  return values[0] ?? '';
}

function normalizeAddresses(value) {
  const list = Array.isArray(value) ? value : [value];
  return list.flatMap((entry) => {
    const raw = typeof entry === 'object' && entry ? entry.email ?? entry.address : entry;
    const matches = String(raw ?? '').toLowerCase().match(/[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-z0-9.-]+\.[a-z]{2,}/g);
    return matches ?? [];
  });
}

function lowerCaseHeaders(headers = {}) {
  return Object.fromEntries(Object.entries(headers).map(([key, value]) => [key.toLowerCase(), value]));
}

function parseReferences(value) {
  return (Array.isArray(value) ? value.join(' ') : String(value ?? ''))
    .match(/<[^<>\s]+>/g)?.slice(-50) ?? [];
}

function validDate(value) {
  const date = new Date(value ?? '');
  return Number.isNaN(date.valueOf()) ? new Date() : date;
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (character) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[character]);
}
