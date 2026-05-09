# Secret Rotation + Webhook Setup (Fast, Safe, Simple)
Date: 2026-05-06

This is the best, lowest-hassle approach: keep all secrets ONLY in Render environment variables and never keep keys in the repo or app folders.

---

## 1) Rotate Razorpay keys (assume compromise)
1. Go to Razorpay Dashboard -> Settings -> API Keys.
2. Generate a new key pair (key_id + key_secret).
3. Immediately deactivate or delete the old key pair.

Update Render env vars:
- RAZORPAY_KEY_ID
- RAZORPAY_KEY_SECRET

Notes:
- Treat old keys as compromised.
- If you run separate test/prod, rotate both and keep them separate.

---

## 2) Rotate Razorpay webhook secret
1. Razorpay Dashboard -> Settings -> Webhooks -> Add/Update webhook.
2. URL: https://<your-backend>/payment/webhook
3. Generate a new webhook secret.
4. Save the webhook.

Update Render env var:
- RAZORPAY_WEBHOOK_SECRET

Important:
- If you change the webhook secret, you must update Render immediately or all webhook calls will fail.

---

## 3) Rotate Firebase service account (assume compromise)
1. Google Cloud Console -> IAM & Admin -> Service Accounts.
2. Find the service account used by your backend.
3. Create a NEW key (JSON) for that account.
4. Delete ALL old keys for that service account.

Update Render env var:
- FIREBASE_SERVICE_ACCOUNT_JSON

How to store it safely in Render:
- Use the full JSON string in a single line.
- Keep the \n escapes inside the private_key field.
- Do NOT wrap the JSON in extra quotes.

Example (redacted):
{"type":"service_account","project_id":"...","private_key":"-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n","client_email":"..."}

---

## 4) DO NOT keep .env or serviceAccountKey.json in the repo
Best practice (lowest hassle + safest):
- Keep all secrets ONLY in Render environment variables.
- Do NOT store serviceAccountKey.json anywhere in the repo or app directories.
- Do NOT commit .env files.

If you need local development:
- Use a local .env file that is ignored by git.
- Never share that file; never upload it.

---

## 5) Configure Razorpay webhook
Webhook URL:
https://<your-backend>/payment/webhook

Events to enable (minimum):
- payment.captured
- payment.failed

(You can add order.paid, refund.processed, etc. later.)

---

## 6) Run Flutter pub get
From the project root:
flutter pub get

---

## 7) Deploy backend with new secrets
On Render:
- Update env vars in the service settings.
- Trigger a deploy (push new commit or manual deploy).

Verify:
- GET https://<your-backend>/health returns {"status":"ok"}.
- Razorpay webhook delivery shows 200 OK.

---

## 8) Reconciliation job (optional but recommended)
Purpose: handle any payments stuck in status "pending" if a webhook fails.

Simple approach (recommended for your stack):
- Add a backend endpoint: POST /payment/reconcile
- It should:
  1) Query Firestore for transactions with status == "pending".
  2) For each, fetch payment/order from Razorpay.
  3) If captured and valid -> mark success.
  4) If failed -> mark failed.

Scheduling options:
- Render Cron Job (best if available in your plan).
- GitHub Actions scheduled workflow hitting the endpoint.
- Any external cron service with a secret token.

Security:
- Protect /payment/reconcile with a secret token or IP allowlist.

---

## Final Answer: Should you add serviceAccountKey.json and .env to Render?
Yes, but only as Render environment variables.
No, never keep serviceAccountKey.json or .env in the repo or app folders.

This is the safest, simplest, and lowest-hassle setup.
