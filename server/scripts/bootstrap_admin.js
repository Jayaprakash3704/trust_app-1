const crypto = require('crypto');
const dotenv = require('dotenv');
const { admin, getAuth, getDb, initFirebaseAdmin } = require('../utils/firebase');
const { hashValue, last4, normalizeAadhaar, normalizePan } = require('../utils/pii');

dotenv.config();
initFirebaseAdmin();

function generateTempPassword() {
  return crypto.randomBytes(12).toString('base64url');
}

async function main() {
  const email = process.env.BOOTSTRAP_ADMIN_EMAIL;
  const name = process.env.BOOTSTRAP_ADMIN_NAME;
  const phone = process.env.BOOTSTRAP_ADMIN_PHONE;
  const address = process.env.BOOTSTRAP_ADMIN_ADDRESS;
  const aadhaar = process.env.BOOTSTRAP_ADMIN_AADHAAR;
  const pan = process.env.BOOTSTRAP_ADMIN_PAN;

  if (!email || !name || !phone || !address || !aadhaar || !pan) {
    throw new Error('Missing bootstrap admin env values');
  }

  let userRecord;
  try {
    userRecord = await getAuth().getUserByEmail(email);
  } catch (error) {
    const tempPassword = generateTempPassword();
    userRecord = await getAuth().createUser({
      email,
      password: tempPassword,
      displayName: name,
    });
  }

  await getAuth().setCustomUserClaims(userRecord.uid, { role: 'admin' });
  const resetLink = await getAuth().generatePasswordResetLink(email);

  const normalizedAadhaar = normalizeAadhaar(aadhaar);
  const normalizedPan = normalizePan(pan);

  const db = getDb();
  await db.collection('users').doc(userRecord.uid).set({
    name,
    phone,
    address,
    role: 'admin',
    aadhaar_last4: last4(normalizedAadhaar),
    aadhaar_hash: hashValue(normalizedAadhaar),
    pan_last4: last4(normalizedPan),
    pan_hash: hashValue(normalizedPan),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // eslint-disable-next-line no-console
  console.log('Admin UID:', userRecord.uid);
  // eslint-disable-next-line no-console
  console.log('Password reset link:', resetLink);
}

main().catch((error) => {
  // eslint-disable-next-line no-console
  console.error(error);
  process.exit(1);
});
