import {createHmac, timingSafeEqual} from 'node:crypto';
import sanitizeHtml from 'sanitize-html';

export const SUPPORT_INBOXES = [
  'hello@howbuddy.app',
  'support@howbuddy.app',
  'contact@howbuddy.app',
];
export const SUPPORT_FORWARD_TO = 'vlobarev823@gmail.com';

const safeHtmlOptions = {
  allowedTags: [
    'a', 'b', 'blockquote', 'br', 'code', 'div', 'em', 'font', 'h1', 'h2', 'h3',
    'hr', 'i', 'img', 'li', 'ol', 'p', 'pre', 'span', 'strong', 'table', 'tbody',
    'td', 'th', 'thead', 'tr', 'ul',
  ],
  allowedAttributes: {
    a: ['href', 'title'],
    font: ['color', 'face', 'size'],
    img: ['src', 'alt', 'width', 'height'],
    td: ['colspan', 'rowspan'],
    th: ['colspan', 'rowspan'],
  },
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
    if (stored.rowCount) {
      await forwardStoredEmail(emailId);
      return {duplicate: true};
    }

    const email = await resend(`/emails/receiving/${encodeURIComponent(emailId)}`);
    const recipients = [...new Set([
      ...normalizeAddresses(email.to), ...normalizeAddresses(email.received_for),
    ])];
    const inbox = recipients.find((address) => SUPPORT_INBOXES.includes(address));
    if (!inbox) return {ignored: true};
    const sender = normalizeAddress(email.from);
    if (!sender) return {ignored: true};
    const toAddresses = normalizeAddresses(email.to);
    const ccAddresses = normalizeAddresses(email.cc);
    const bccAddresses = normalizeAddresses(email.bcc);
    const replyToAddresses = normalizeAddresses(email.reply_to ?? email.replyTo);
    const receivedFor = normalizeAddresses(email.received_for);
    const senderName = extractDisplayName(email.from);
    const headers = lowerCaseHeaders(email.headers);
    const messageId = String(email.message_id ?? headers['message-id'] ?? '').trim();
    const inReplyTo = String(email.in_reply_to ?? headers['in-reply-to'] ?? '').trim();
    const references = parseReferences(email.references ?? headers.references ?? '');
    const subject = String(email.subject ?? '').replace(/[\r\n]+/g, ' ').slice(0, 998);
    const textBody = String(email.text ?? email.text_body ?? '').slice(0, 1_000_000);
    const htmlBody = sanitizeEmailHtml(email.html ?? email.html_body ?? '').slice(0, 1_000_000);
    const receivedAt = validDate(email.created_at ?? email.received_at);
    const client = await pool.connect();
    let clientReleased = false;
    try {
      await client.query('BEGIN');
      await client.query('SELECT pg_advisory_xact_lock(hashtextextended($1, 0))', [emailId]);
      const duplicate = await client.query(
        'SELECT id FROM support_messages WHERE provider_email_id = $1 FOR UPDATE', [emailId],
      );
      if (duplicate.rowCount) {
        await client.query('ROLLBACK');
        client.release();
        clientReleased = true;
        await forwardStoredEmail(emailId);
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
         (conversation_id, direction, sender_email, sender_name, recipient_email, cc_emails,
          bcc_emails, reply_to_emails, received_for, email_headers, subject, text_body, html_body,
          provider_email_id, message_id, in_reply_to, references_header, received_at)
         VALUES ($1, 'inbound', $2, $3, $4, $5, $6, $7, $8, $9::jsonb, $10, $11, $12, $13, $14, $15, $16, $17)
         ON CONFLICT (provider_email_id) DO NOTHING RETURNING id`,
        [conversation.id, sender, senderName, toAddresses.join(', ') || inbox,
          ccAddresses, bccAddresses, replyToAddresses, receivedFor,
          JSON.stringify(headersForStorage(email.headers)), subject, textBody, htmlBody,
          emailId, messageId, inReplyTo, references, receivedAt],
      );
      for (const attachment of (inserted.rows[0] ? (email.attachments ?? []) : [])) {
        const attachmentId = String(attachment.id ?? attachment.attachment_id ?? '');
        if (!attachmentId) continue;
        await client.query(
          `INSERT INTO support_attachments
           (message_id, provider_attachment_id, filename, content_type, size_bytes, content_disposition, content_id)
           VALUES ($1, $2, $3, $4, $5, $6, $7) ON CONFLICT DO NOTHING`,
          [inserted.rows[0]?.id, attachmentId,
            String(attachment.filename ?? 'attachment').slice(0, 255),
            String(attachment.content_type ?? attachment.contentType ?? 'application/octet-stream').slice(0, 255),
            Math.max(0, Number(attachment.size ?? 0)),
            String(attachment.content_disposition ?? 'attachment').slice(0, 100),
            String(attachment.content_id ?? '').slice(0, 500)],
        );
      }
      await client.query('COMMIT');
      client.release();
      clientReleased = true;
      const forwarded = await forwardStoredEmail(emailId);
      return {stored: Boolean(inserted.rowCount), forwarded};
    } catch (error) {
      if (!clientReleased) await client.query('ROLLBACK');
      throw error;
    } finally {
      if (!clientReleased) client.release();
    }
  }

  async function forwardStoredEmail(emailId) {
    // Serialize webhook retries for this message and use Resend's idempotency
    // key in case the provider accepts a send just before a network timeout.
    const client = await pool.connect();
    try {
      await client.query('SELECT pg_advisory_lock(hashtextextended($1, 0))', [`forward:${emailId}`]);
      const result = await client.query(
        `SELECT m.id, m.sender_email, m.sender_name, m.recipient_email, m.cc_emails,
          m.bcc_emails, m.reply_to_emails, m.subject, m.text_body, m.html_body,
          m.received_at, m.forwarded_at, m.provider_email_id,
          COALESCE((SELECT json_agg(json_build_object(
            'id', a.provider_attachment_id, 'filename', a.filename,
            'contentType', a.content_type, 'size', a.size_bytes
          )) FROM support_attachments a WHERE a.message_id = m.id), '[]'::json) AS attachments
         FROM support_messages m WHERE m.provider_email_id = $1 AND m.direction = 'inbound'`,
        [emailId],
      );
      const message = result.rows[0];
      if (!message || message.forwarded_at) return Boolean(message?.forwarded_at);
      const inbox = normalizeAddresses(message.recipient_email)
        .find((address) => SUPPORT_INBOXES.includes(address)) ?? SUPPORT_INBOXES[0];
      const forwardedAttachments = [];
      const omittedAttachments = [];
      let attachmentBytes = 0;
      for (const item of message.attachments ?? []) {
        try {
          const details = await resend(
            `/emails/receiving/${encodeURIComponent(message.provider_email_id)}/attachments/${encodeURIComponent(item.id)}`,
          );
          const url = new URL(details.download_url);
          if (url.protocol !== 'https:' || url.hostname !== 'inbound-cdn.resend.com' || url.username || url.password) {
            throw new Error('Unsafe attachment download URL.');
          }
          const response = await fetchImpl(url, {signal: AbortSignal.timeout(20_000)});
          if (!response.ok) throw new Error(`Attachment download failed (${response.status}).`);
          const data = Buffer.from(await response.arrayBuffer());
          if (attachmentBytes + data.length > 25 * 1024 * 1024) {
            omittedAttachments.push(item.filename);
            continue;
          }
          attachmentBytes += data.length;
          forwardedAttachments.push({
            filename: String(item.filename || 'attachment').slice(0, 255),
            content_type: String(item.contentType || 'application/octet-stream').slice(0, 255),
            content: data.toString('base64'),
          });
        } catch (error) {
          logger.warn(`Could not include inbound attachment ${item.filename}:`, error.message);
          omittedAttachments.push(item.filename);
        }
      }
      const originalText = message.text_body || stripHtml(message.html_body);
      const cc = (message.cc_emails ?? []).join(', ');
      const bcc = (message.bcc_emails ?? []).join(', ');
      const replyTo = (message.reply_to_emails ?? []).join(', ');
      const extra = omittedAttachments.length
        ? `\n\nSome attachments could not be included: ${omittedAttachments.join(', ')}. They remain available in the HowBuddy admin inbox.`
        : '';
      const text = [
        `Forwarded from: ${message.sender_name ? `${message.sender_name} ` : ''}<${message.sender_email}>`,
        `Received by: ${message.recipient_email}`,
        ...(cc ? [`Cc: ${cc}`] : []),
        ...(bcc ? [`Bcc: ${bcc}`] : []),
        ...(replyTo ? [`Reply-to: ${replyTo}`] : []),
        `Received at: ${new Date(message.received_at).toISOString()}`,
        `Subject: ${message.subject || '(no subject)'}`,
        '',
        originalText,
        extra,
      ].join('\n');
      const originalHtml = message.html_body || `<pre>${escapeHtml(originalText)}</pre>`;
      const sent = await resend('/emails', {
        method: 'POST',
        headers: {'Idempotency-Key': `howbuddy-inbound-${message.id}`},
        body: JSON.stringify({
          from: `${inbox.split('@')[0]} <${inbox}>`,
          to: [SUPPORT_FORWARD_TO],
          reply_to: message.sender_email,
          subject: `[HowBuddy] ${message.subject || '(no subject)'}`.slice(0, 998),
          text,
          html: `<p><strong>Forwarded from:</strong> ${escapeHtml(message.sender_name ? `${message.sender_name} ` : '')}&lt;${escapeHtml(message.sender_email)}&gt;</p><p><strong>Received by:</strong> ${escapeHtml(message.recipient_email)}</p>${cc ? `<p><strong>Cc:</strong> ${escapeHtml(cc)}</p>` : ''}${bcc ? `<p><strong>Bcc:</strong> ${escapeHtml(bcc)}</p>` : ''}${replyTo ? `<p><strong>Reply-to:</strong> ${escapeHtml(replyTo)}</p>` : ''}<p><strong>Received at:</strong> ${escapeHtml(new Date(message.received_at).toISOString())}</p><p><strong>Subject:</strong> ${escapeHtml(message.subject || '(no subject)')}</p><hr>${originalHtml}${omittedAttachments.length ? `<p>Some attachments were omitted: ${escapeHtml(omittedAttachments.join(', '))}. They remain available in the HowBuddy admin inbox.</p>` : ''}`,
          attachments: forwardedAttachments,
        }),
      });
      if (!sent.id) throw new Error('Resend did not confirm the forwarded email.');
      await client.query('UPDATE support_messages SET forwarded_at = now() WHERE id = $1', [message.id]);
      return true;
    } finally {
      await client.query('SELECT pg_advisory_unlock(hashtextextended($1, 0))', [`forward:${emailId}`]);
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
          (SELECT COALESCE(NULLIF(m.text_body, ''), regexp_replace(m.html_body, '<[^>]*>', ' ', 'g'))
           FROM support_messages m WHERE m.conversation_id = c.id
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
            'senderName', m.sender_name, 'recipientEmail', m.recipient_email,
            'ccEmails', m.cc_emails, 'bccEmails', m.bcc_emails,
            'replyToEmails', m.reply_to_emails, 'receivedFor', m.received_for,
            'headers', m.email_headers, 'forwardedAt', m.forwarded_at,
            'subject', m.subject,
            'text', m.text_body, 'html', m.html_body, 'messageId', m.message_id,
            'inReplyTo', m.in_reply_to, 'references', m.references_header,
            'receivedAt', m.received_at,
            'attachments', COALESCE((SELECT jsonb_agg(jsonb_build_object(
              'id', a.id, 'filename', a.filename, 'contentType', a.content_type,
              'size', a.size_bytes, 'contentDisposition', a.content_disposition,
              'contentId', a.content_id
            )) FROM support_attachments a WHERE a.message_id = m.id), '[]'::jsonb)
              || COALESCE(m.sent_attachments, '[]'::jsonb)
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

    async reply(id, text, requestedAttachments = []) {
      const body = String(text ?? '').trim();
      if (requestedAttachments == null) requestedAttachments = [];
      if ((!body && !requestedAttachments.length) || body.length > 50_000) {
        throw new Error('Write a reply or attach a file. Replies must be under 50,000 characters.');
      }
      if (!Array.isArray(requestedAttachments) || requestedAttachments.length > 10) {
        throw new Error('Attach up to 10 files per reply.');
      }
      const attachments = [];
      let totalBytes = 0;
      for (const item of requestedAttachments) {
        const filename = String(item?.filename ?? 'attachment')
          .replace(/[\\/]/g, '_').replace(/[\u0000-\u001f\u007f]/g, '').trim().slice(0, 255) || 'attachment';
        const encoded = item?.content;
        if (typeof encoded !== 'string' || encoded.length % 4 !== 0 || !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(encoded)) {
          throw new Error(`The attachment ${filename} is not valid.`);
        }
        const content = Buffer.from(encoded, 'base64');
        totalBytes += content.length;
        if (totalBytes > 25 * 1024 * 1024) {
          throw new Error('Attachments must total 25 MB or less.');
        }
        const requestedType = String(item?.contentType ?? 'application/octet-stream');
        const contentType = /^[\w!#$&^_.+-]+\/[\w!#$&^_.+-]+$/.test(requestedType)
          ? requestedType.slice(0, 255)
          : 'application/octet-stream';
        attachments.push({filename, contentType, content});
      }
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
          ...(attachments.length ? {attachments: attachments.map((item) => ({
            filename: item.filename,
            content_type: item.contentType,
            content: item.content.toString('base64'),
          }))} : {}),
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
          message_id, in_reply_to, references_header, sent_attachments, received_at)
         VALUES ($1, 'outbound', $2, $3, $4, $5, $6, $7, $8, $9, $10::jsonb, now())`,
        [id, conversation.inbox_address, conversation.sender_email, subject, body, providerId,
          providerMessageId, last?.messageId ?? '', references,
          JSON.stringify(attachments.map((item) => ({
            filename: item.filename,
            contentType: item.contentType,
            size: item.content.length,
            contentDisposition: 'attachment',
          })))],
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

function extractDisplayName(value) {
  const entry = Array.isArray(value) ? value[0] : value;
  if (entry && typeof entry === 'object') {
    return String(entry.name ?? entry.display_name ?? '').trim().slice(0, 255);
  }
  const raw = String(entry ?? '');
  const match = raw.match(/^\s*(.*?)\s*<[^<>]+>\s*$/);
  return String(match?.[1] ?? '').replace(/^['"]|['"]$/g, '').trim().slice(0, 255);
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
  const source = headers && typeof headers === 'object' ? headers : {};
  return Object.fromEntries(Object.entries(source).map(([key, value]) => [key.toLowerCase(), value]));
}

function headersForStorage(headers = {}) {
  const source = headers && typeof headers === 'object' ? headers : {};
  return Object.fromEntries(Object.entries(source).slice(0, 100).map(([key, value]) => [
    String(key).slice(0, 255),
    (Array.isArray(value) ? value : [value])
      .map((item) => String(item ?? '').slice(0, 4000))
      .join('\n')
      .slice(0, 4000),
  ]));
}

function stripHtml(value) {
  return sanitizeHtml(String(value ?? ''), {allowedTags: [], allowedAttributes: {}})
    .replace(/\s+/g, ' ').trim();
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
