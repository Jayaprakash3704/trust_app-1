const crypto = require('crypto');
const { z } = require('zod');
const { admin, getAuth, getDb } = require('../utils/firebase');
const { sendPasswordResetEmail } = require('../utils/email');
const {
  hashValue,
  last4,
  normalizeAadhaar,
  normalizePan,
} = require('../utils/pii');

const createUserSchema = z
  .object({
    email: z.string().email(),
    name: z.string().min(1),
    phone: z.string().min(1),
    address: z.string().min(1),
    aadhaar: z.string().regex(/^\d{12}$/, 'Aadhaar must be 12 digits'),
    pan: z
      .string()
      .regex(
        /^[A-Z]{5}[0-9]{4}[A-Z]$/,
        'PAN must be 5 letters, 4 numbers, 1 letter',
      ),
  })
  .strict();

const updateUserSchema = z.object({
  userId: z.string().min(1),
  name: z.string().min(1).optional(),
  phone: z.string().min(1).optional(),
  address: z.string().min(1).optional(),
  aadhaar: z
    .string()
    .regex(/^\d{12}$/, 'Aadhaar must be 12 digits')
    .optional(),
  pan: z
    .string()
    .regex(
      /^[A-Z]{5}[0-9]{4}[A-Z]$/,
      'PAN must be 5 letters, 4 numbers, 1 letter',
    )
    .optional(),
});

const resetLinkSchema = z.object({
  userId: z.string().min(1),
});

function generateTempPassword() {
  return crypto.randomBytes(12).toString('base64url');
}

function buildPiiPayload(aadhaar, pan) {
  const normalizedAadhaar = normalizeAadhaar(aadhaar);
  const normalizedPan = normalizePan(pan);

  if (normalizedAadhaar.length < 4 || normalizedPan.length < 4) {
    throw new Error('Aadhaar/PAN must be valid');
  }

  return {
    aadhaar_last4: last4(normalizedAadhaar),
    aadhaar_hash: hashValue(normalizedAadhaar),
    pan_last4: last4(normalizedPan),
    pan_hash: hashValue(normalizedPan),
  };
}

async function createUser(req, res) {
  const parsed = createUserSchema.safeParse(req.body);
  if (!parsed.success) {
    return res
      .status(400)
      .json({ error: parsed.error.issues[0]?.message ?? 'Invalid user payload' });
  }

  const { email, name, phone, address, aadhaar, pan } = parsed.data;
  const role = 'user';
  let userRecord;
  let resetLink = null;

  try {
    userRecord = await getAuth().getUserByEmail(email);
    await getAuth().updateUser(userRecord.uid, { displayName: name });
  } catch (error) {
    if (error.code !== 'auth/user-not-found') {
      throw error;
    }

    const tempPassword = generateTempPassword();
    userRecord = await getAuth().createUser({
      email,
      password: tempPassword,
      displayName: name,
    });
  }

  const hasPasswordProvider = (userRecord.providerData || []).some(
    (provider) => provider.providerId === 'password',
  );
  if (!hasPasswordProvider) {
    const tempPassword = generateTempPassword();
    await getAuth().updateUser(userRecord.uid, { password: tempPassword });
  }

  resetLink = await getAuth().generatePasswordResetLink(email);

  let emailResult = { sent: false };
  try {
    emailResult = await sendPasswordResetEmail({
      to: email,
      name,
      resetLink,
    });
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('Failed to send reset email:', error.message);
  }

  await getAuth().setCustomUserClaims(userRecord.uid, { role });

  const db = getDb();
  await db.collection('users').doc(userRecord.uid).set({
    name,
    phone,
    address,
    role,
    ...buildPiiPayload(aadhaar, pan),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return res.json({
    passwordResetLink: resetLink,
    emailSent: emailResult.sent,
  });
}

async function updateUser(req, res) {
  const parsed = updateUserSchema.safeParse(req.body);
  if (!parsed.success) {
    return res
      .status(400)
      .json({ error: parsed.error.issues[0]?.message ?? 'Invalid update payload' });
  }

  const { userId, aadhaar, pan, ...rest } = parsed.data;
  const updatePayload = { ...rest };

  if (aadhaar || pan) {
    const aadhaarValue = aadhaar ?? '';
    const panValue = pan ?? '';
    Object.assign(updatePayload, buildPiiPayload(aadhaarValue, panValue));
  }

  const db = getDb();
  await db.collection('users').doc(userId).set(updatePayload, { merge: true });

  return res.json({ status: 'updated' });
}

async function createResetLink(req, res) {
  const parsed = resetLinkSchema.safeParse(req.body);
  if (!parsed.success) {
    return res
      .status(400)
      .json({ error: parsed.error.issues[0]?.message ?? 'Invalid reset payload' });
  }

  const { userId } = parsed.data;

  let userRecord;
  try {
    userRecord = await getAuth().getUser(userId);
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      return res.status(404).json({ error: 'User not found.' });
    }
    throw error;
  }

  const email = userRecord.email;
  if (!email) {
    return res.status(400).json({ error: 'User does not have an email address.' });
  }

  const resetLink = await getAuth().generatePasswordResetLink(email);

  let emailResult = { sent: false };
  try {
    emailResult = await sendPasswordResetEmail({
      to: email,
      name: userRecord.displayName || '',
      resetLink,
    });
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('Failed to send reset email:', error.message);
  }

  return res.json({
    passwordResetLink: resetLink,
    emailSent: emailResult.sent,
  });
}

module.exports = {
  createUser,
  updateUser,
  createResetLink,
};
