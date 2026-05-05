const admin = require('firebase-admin');

let initialized = false;

function initFirebaseAdmin() {
  if (initialized) {
    return;
  }

  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!serviceAccountJson) {
    throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON is required');
  }

  let serviceAccount;
  try {
    serviceAccount = JSON.parse(serviceAccountJson);
  } catch (error) {
    throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON must be valid JSON');
  }

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  initialized = true;
}

function getDb() {
  return admin.firestore();
}

function getAuth() {
  return admin.auth();
}

module.exports = {
  admin,
  getAuth,
  getDb,
  initFirebaseAdmin,
};
