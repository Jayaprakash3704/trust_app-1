# Render.com Server Setup

This guide configures the Express server in `server/` for deployment on Render.

## 1. Create the Web Service

1. Create a new Web Service on Render and connect this repository.
2. Set Root Directory to `server`.
3. Use the build and start commands below.
4. Set the health check path to `/health`.

## 2. Build and Start Commands

- Build Command: `npm install`
- Start Command: `npm start`

Render injects `PORT`, so you can omit it from your config unless you want to override it.

## 3. Environment Variables

Set these in the Render service environment. Values come from `server/.env.example`.

Required for all deployments:

- `FIREBASE_SERVICE_ACCOUNT_JSON`: Full service account JSON, on a single line.
- `PII_HASH_SECRET`: Secret used to hash PII (must be stable across deploys).
- `RAZORPAY_KEY_ID`: Razorpay key id.
- `RAZORPAY_KEY_SECRET`: Razorpay key secret.
- `RAZORPAY_WEBHOOK_SECRET`: Razorpay webhook secret.

Optional but recommended:

- `ALLOWED_ORIGINS`: Comma-separated list of allowed CORS origins.

Optional (only for admin bootstrap):

- `BOOTSTRAP_ADMIN_EMAIL`
- `BOOTSTRAP_ADMIN_NAME`
- `BOOTSTRAP_ADMIN_PHONE`
- `BOOTSTRAP_ADMIN_ADDRESS`
- `BOOTSTRAP_ADMIN_AADHAAR`
- `BOOTSTRAP_ADMIN_PAN`

Notes on `FIREBASE_SERVICE_ACCOUNT_JSON`:

- It must be valid JSON, on a single line.
- The `private_key` field should keep its `\n` escapes.
- Do not wrap the JSON in extra quotes.

Example (redacted) structure:

```
{"type":"service_account","project_id":"...","private_key":"-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n","client_email":"...","client_id":"..."}
```

## 4. Admin Bootstrap (One-Time)

The script `npm run bootstrap:admin`:

- Creates the admin user in Firebase Auth if it does not exist.
- Sets the custom claim `{ role: "admin" }`.
- Writes a Firestore `users/{uid}` document with hashed PII and last4 fields.
- Prints the admin UID and a password reset link.

Steps:

1. Add the `BOOTSTRAP_ADMIN_*` variables (and the required Firebase/PII vars) to the Render service.
2. Run the script once in an environment that can access the same Render env vars:
   - Render one-off job (preferred), or
   - Render service shell (if available), or
   - Local terminal with the same env values.

Command:

```
npm run bootstrap:admin
```

3. Save the password reset link output and complete the password reset for the admin user.
4. Remove the `BOOTSTRAP_ADMIN_*` variables after success to avoid accidental re-runs.

Re-running the script will update the Firestore `users/{uid}` document with the new values.

## 5. Verify

- Health check: `GET /health` should return `{ "status": "ok" }`.
- Review Render logs for startup errors.
