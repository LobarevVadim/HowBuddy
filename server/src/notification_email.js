const EMAIL_TEST_RECIPIENT = 'vlobarev823@gmail.com';
const HOWBUDDY_WEB_URL = 'https://howbuddy-demo-web.onrender.com';

export function isEmailTestRecipient(email) {
  return String(email ?? '').trim().toLowerCase() === EMAIL_TEST_RECIPIENT;
}

export function createNotificationEmailSender({
  apiKey = '',
  from = '',
  fetchImpl = fetch,
  logger = console,
}) {
  return async function sendNotificationEmail({email, title, body, topicId = ''}) {
    if (!isEmailTestRecipient(email)) return {sent: false, reason: 'recipient-filtered'};
    if (!apiKey || !from) return {sent: false, reason: 'email-not-configured'};

    const targetUrl = topicId
      ? `${HOWBUDDY_WEB_URL}/?notificationTopic=${encodeURIComponent(topicId)}`
      : `${HOWBUDDY_WEB_URL}/`;
    const text = `${title}\n\n${body}\n\nOpen HowBuddy: ${targetUrl}`;
    const html = [title, body, `<a href="${escapeAttribute(targetUrl)}">Open HowBuddy</a>`]
      .filter(Boolean)
      .map((part) => `<p>${typeof part === 'string' && part.startsWith('<a ')
        ? part
        : escapeHtml(part)}</p>`)
      .join('');

    let response;
    try {
      response = await fetchImpl('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from,
          to: [EMAIL_TEST_RECIPIENT],
          subject: title,
          text,
          html,
        }),
        signal: AbortSignal.timeout(10_000),
      });
    } catch (error) {
      logger.error('Notification email request failed:', error.message);
      return {sent: false, reason: 'provider-error'};
    }

    if (!response.ok) {
      logger.error(`Notification email provider returned HTTP ${response.status}.`);
      return {sent: false, reason: 'provider-error'};
    }
    return {sent: true};
  };
}

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (character) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  })[character]);
}

function escapeAttribute(value) {
  return escapeHtml(value);
}
