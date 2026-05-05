const crypto = require('crypto');

function getHashSecret() {
  const secret = process.env.PII_HASH_SECRET;
  if (!secret) {
    throw new Error('PII_HASH_SECRET is required');
  }
  return secret;
}

function normalizeAadhaar(value) {
  return String(value ?? '').replace(/\D/g, '');
}

function normalizePan(value) {
  return String(value ?? '').replace(/[^a-zA-Z0-9]/g, '').toUpperCase();
}

function hashValue(value) {
  const secret = getHashSecret();
  return crypto.createHmac('sha256', secret).update(value).digest('hex');
}

function last4(value) {
  return value.slice(-4);
}

module.exports = {
  hashValue,
  last4,
  normalizeAadhaar,
  normalizePan,
};
