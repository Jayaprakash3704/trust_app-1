const nodemailer = require('nodemailer');

const {
  SMTP_USER,
  SMTP_APP_PASSWORD,
  EMAIL_FROM_NAME,
  EMAIL_REPLY_TO,
  APP_NAME,
  APP_LOGO_URL,
  APP_WEB_URL,
} = process.env;

let cachedTransporter;

function isEmailConfigured() {
  return Boolean(SMTP_USER && SMTP_APP_PASSWORD);
}

function getTransporter() {
  if (!cachedTransporter) {
    cachedTransporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: SMTP_USER,
        pass: SMTP_APP_PASSWORD,
      },
    });
  }

  return cachedTransporter;
}

function escapeHtml(value) {
  if (!value) {
    return '';
  }

  return value.replace(/[&<>"']/g, (char) => {
    switch (char) {
      case '&':
        return '&amp;';
      case '<':
        return '&lt;';
      case '>':
        return '&gt;';
      case '"':
        return '&quot;';
      case "'":
        return '&#39;';
      default:
        return char;
    }
  });
}

function buildResetEmail({ recipientName, resetLink }) {
  const appName = APP_NAME || 'Trust App';
  const safeName = escapeHtml(recipientName);
  const greeting = safeName ? `Hi ${safeName},` : 'Hi,';
  const logoHtml = APP_LOGO_URL
    ? `<img src="${APP_LOGO_URL}" alt="${appName}" style="max-width:160px;margin-bottom:12px;" />`
    : '';
  const webUrl = APP_WEB_URL || '';
  const webLinkHtml = webUrl
    ? `<p style="margin:0 0 16px 0;font-size:14px;">Visit <a href="${webUrl}">${appName}</a>.</p>`
    : '';

  const html = `
    <div style="font-family:Arial,Helvetica,sans-serif;max-width:560px;margin:0 auto;padding:24px;color:#111;">
      ${logoHtml}
      <p style="margin:0 0 12px 0;font-size:16px;">${greeting}</p>
      <p style="margin:0 0 16px 0;font-size:14px;">We received a request to reset your ${appName} password.</p>
      <p style="margin:0 0 20px 0;">
        <a href="${resetLink}" style="background:#1f2937;color:#fff;text-decoration:none;padding:10px 18px;border-radius:6px;display:inline-block;">Reset password</a>
      </p>
      <p style="margin:0 0 16px 0;font-size:14px;">If you did not request this, you can ignore this email.</p>
      ${webLinkHtml}
      <p style="margin:0;font-size:12px;color:#6b7280;">This link expires according to your Firebase Auth settings.</p>
    </div>
  `;

  const text = [
    greeting,
    `We received a request to reset your ${appName} password.`,
    `Reset password: ${resetLink}`,
    'If you did not request this, you can ignore this email.',
    webUrl ? `Visit ${appName}: ${webUrl}` : '',
  ]
    .filter(Boolean)
    .join('\n\n');

  return {
    subject: `${appName} password reset`,
    html,
    text,
  };
}

async function sendPasswordResetEmail({ to, name, resetLink }) {
  if (!isEmailConfigured()) {
    return { sent: false, reason: 'not_configured' };
  }

  if (!to || !resetLink) {
    throw new Error('Missing email or reset link');
  }

  const transporter = getTransporter();
  const { subject, html, text } = buildResetEmail({
    recipientName: name,
    resetLink,
  });
  const fromName = (EMAIL_FROM_NAME || APP_NAME || 'Trust App').trim();
  const from = fromName ? `${fromName} <${SMTP_USER}>` : SMTP_USER;
  const message = {
    from,
    to,
    subject,
    html,
    text,
  };

  if (EMAIL_REPLY_TO) {
    message.replyTo = EMAIL_REPLY_TO;
  }

  await transporter.sendMail(message);
  return { sent: true };
}

module.exports = {
  isEmailConfigured,
  sendPasswordResetEmail,
};
