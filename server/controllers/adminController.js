const crypto = require('crypto');
const { z } = require('zod');
const { admin, getAuth, getDb } = require('../utils/firebase');
const {
  hashValue,
  last4,
  normalizeAadhaar,
  normalizePan,
} = require('../utils/pii');

const createUserSchema = z
  .object({
    existingUid: z.string().min(1).optional(),
    email: z.string().email().optional(),
    name: z.string().min(1),
    phone: z.string().min(1),
    address: z.string().min(1),
    aadhaar: z.string().min(8),
    pan: z.string().min(6),
    role: z.enum(['admin', 'user']).default('user'),
  })
  .refine((data) => data.existingUid || data.email, {
    message: 'Either existingUid or email is required',
  });

const updateUserSchema = z.object({
  userId: z.string().min(1),
  name: z.string().min(1).optional(),
  phone: z.string().min(1).optional(),
  address: z.string().min(1).optional(),
  aadhaar: z.string().min(8).optional(),
  pan: z.string().min(6).optional(),
  role: z.enum(['admin', 'user']).optional(),
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
    return res.status(400).json({ error: 'Invalid user payload' });
  }

  const { existingUid, email, name, phone, address, aadhaar, pan, role } =
    parsed.data;
  let userRecord;
  let resetLink = null;

  if (existingUid) {
    userRecord = await getAuth().getUser(existingUid);
    await getAuth().updateUser(existingUid, { displayName: name });
  } else {
    const tempPassword = generateTempPassword();
    userRecord = await getAuth().createUser({
      email,
      password: tempPassword,
      displayName: name,
    });
    resetLink = await getAuth().generatePasswordResetLink(email);
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
    uid: userRecord.uid,
    passwordResetLink: resetLink,
  });
}

async function updateUser(req, res) {
  const parsed = updateUserSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: 'Invalid update payload' });
  }

  const { userId, aadhaar, pan, role, ...rest } = parsed.data;
  const updatePayload = { ...rest };

  if (aadhaar || pan) {
    const aadhaarValue = aadhaar ?? '';
    const panValue = pan ?? '';
    Object.assign(updatePayload, buildPiiPayload(aadhaarValue, panValue));
  }

  if (role) {
    await getAuth().setCustomUserClaims(userId, { role });
    updatePayload.role = role;
  }

  const db = getDb();
  await db.collection('users').doc(userId).set(updatePayload, { merge: true });

  return res.json({ status: 'updated' });
}

module.exports = {
  createUser,
  updateUser,
};
