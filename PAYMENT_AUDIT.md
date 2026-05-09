# Payment Security Audit - trust_app
Date: 2026-05-06

Scope reviewed (code only):
- server/index.js
- server/routes/payment.js
- server/controllers/paymentController.js
- server/utils/razorpay.js
- server/utils/pii.js
- server/utils/firebase.js
- server/middlewares/auth.js
- server/.env.example (and the presence of server/.env in workspace)
- lib/services/payment_service.dart
- lib/features/user/payment/payment_screen.dart
- lib/core/constants/fee_rules.dart
- lib/core/constants/app_config.dart
- lib/core/models/transaction.dart
- lib/services/firestore_service.dart
- firestore.rules
- android/app/build.gradle.kts
- android/app/serviceAccountKey.json (presence in workspace)

Observed architecture (current implementation)
1) Flutter uses Firebase Auth ID tokens to call backend endpoints in server/routes/payment.js.
2) create-order: server/controllers/paymentController.js computes fee, creates a Razorpay order, then writes a Firestore transactions/{transactionId} document with status=created.
3) Flutter opens Razorpay Checkout using keyId, order_id, amount and notes from the create-order response.
4) On Razorpay success callback, Flutter calls /payment/verify-payment with transactionId, razorpay_order_id, razorpay_payment_id, razorpay_signature.
5) Backend verifies HMAC signature using RAZORPAY_KEY_SECRET and sets status=success, razorpay_payment_id.
6) On Razorpay error callback, Flutter calls /payment/payment-failed and backend sets status=failed.
7) There is no webhook endpoint and no server-side fetch of Razorpay order/payment status.

Findings (ordered by severity)

F1 - CRITICAL - Secrets present in workspace (high risk of key compromise and fake payments)
Severity: Critical
Evidence: server/.env exists in workspace (contains Razorpay key secret and PII hash secret). android/app/serviceAccountKey.json exists in workspace.
Exploitation: If either file is committed, shared, or leaked, an attacker can forge Razorpay signatures, mark any order as paid, and access Firestore with service account privileges.
Consequence: Unlimited fake payments, permanent compromise of PII hashes, and potential full Firebase project compromise.
Fix: Remove sensitive files from the repo and build artifacts immediately, rotate Razorpay key secret and PII_HASH_SECRET, rotate Firebase service account, and ensure secrets only live in Render env vars or a secret manager.

F2 - HIGH - No webhook or server-to-server verification (client callback is the single source of truth)
Severity: High
Evidence: Only /payment/create-order, /payment/verify-payment, /payment/payment-failed exist (server/routes/payment.js). No webhook route in server/index.js.
Exploitation: Any missed client callback (app kill, network loss) leaves a paid order stuck as created. Refunds, chargebacks, and delayed captures are never reflected. A modified client can skip verification and still show success locally.
Consequence: Ledger mismatch, lost revenue, inability to reconcile or handle disputes, and incorrect premium/donation state.
Fix: Add a Razorpay webhook endpoint and verify webhook signatures; update transaction status based on webhook events, not only client callbacks.

F3 - HIGH - Verification trusts client-supplied payment details without Razorpay API validation
Severity: High
Evidence: verifyPayment only recomputes HMAC over order_id|payment_id and writes success (server/controllers/paymentController.js).
Exploitation: If the Razorpay key secret is leaked, payments can be forged trivially. Even without a leak, you do not verify amount, currency, or captured/refunded status.
Consequence: Over-crediting, inability to detect refunds/chargebacks, incorrect donation amounts, and audit failures.
Fix: After signature validation, fetch payment and order from Razorpay API and verify status=captured, amount=expected, currency=INR, and order_id matches the stored transaction.

F4 - HIGH - Unsafe status transitions and race conditions
Severity: High
Evidence: markPaymentFailed sets status=failed unconditionally; verifyPayment sets status=success unconditionally; invalid signatures force status=failed (server/controllers/paymentController.js).
Exploitation: A late /payment/payment-failed call or an invalid verify request can overwrite a successful payment. Network retries or client bugs can flip status.
Consequence: Paid transactions become failed, users lose access, and reconciliation becomes unreliable.
Fix: Use Firestore transactions with conditional updates and a strict state machine (created -> paid -> refunded; never allow paid -> failed).

F5 - MEDIUM - No idempotency for create-order and no reuse of pending orders
Severity: Medium
Evidence: create-order always creates a new order and new Firestore doc; UI calls _prepareOrder on every input change (lib/features/user/payment/payment_screen.dart).
Exploitation: Network retries or user edits can create multiple orders; user can accidentally pay twice; report noise grows with orphaned created orders.
Consequence: Duplicate charges, inflated order counts, and complex reconciliation.
Fix: Add an idempotency key and reuse an existing created order for the same user + intent; expire stale orders.

F6 - MEDIUM - No dedupe of payment_id or webhook event id
Severity: Medium
Evidence: Firestore schema stores razorpay_payment_id but has no uniqueness or claim logic (lib/core/models/transaction.dart).
Exploitation: If duplicate notifications arrive (webhooks or client retries), you can double-credit unless you enforce uniqueness.
Consequence: Duplicate credits and inconsistent totals.
Fix: Store payment_id and webhook_event_id in a dedicated collection and claim them with a Firestore transaction before crediting.

F7 - MEDIUM - Release build uses debug signing key
Severity: Medium
Evidence: android/app/build.gradle.kts uses signingConfigs.debug for release.
Exploitation: Release APKs can be tampered or rejected by stores; integrity guarantees are weak.
Consequence: Supply-chain risk and store compliance failures.
Fix: Add a proper release keystore and signing config.

F8 - MEDIUM - PII hash secret rotation and determinism risk
Severity: Medium
Evidence: PII hashing uses a single secret without versioning (server/utils/pii.js).
Exploitation: If PII_HASH_SECRET leaks, Aadhaar/PAN hashes are vulnerable to dictionary attacks; all hashes become compromised simultaneously.
Consequence: PII re-identification risk and inability to rotate without rehashing.
Fix: Add a hash_version field and support secret rotation; keep PII_HASH_SECRET high-entropy and distinct from other secrets.

F9 - LOW - CORS is open by default
Severity: Low
Evidence: ALLOWED_ORIGINS is optional; if empty, cors() allows all origins (server/index.js).
Exploitation: Not a direct bypass because Firebase ID tokens are still required, but web clients are more exposed to token misuse if a browser app is added later.
Consequence: Expanded attack surface for web clients.
Fix: Restrict origins for browser clients and keep server-to-server auth as the primary guard.

F10 - LOW - Client-side hashing utility could diverge from server hashing
Severity: Low
Evidence: lib/core/utils/hashing.dart uses sha256(value:salt) and is not used by server utilities.
Exploitation: If this is later used for PII, hashes will not match server HMAC outputs.
Consequence: Inconsistent PII handling and audit mismatch.
Fix: Remove or clearly document that PII hashing must be server-only using HMAC.

Direct answers to your questions (code-based)
1) Complete payment architecture: described in Observed architecture section.
2) Security flaws and fraud risks: F1-F6 cover fake payments, race conditions, replay, and webhook issues.
3) Production safety: Not production safe due to test keys, missing webhook, missing server-side verification, and debug signing.
4) Verification correctness: HMAC verification is correct but insufficient; must validate order/payment via Razorpay API and webhook.
5) Client-side trust: Client can trigger final status changes (success/failure) and backend trusts client IDs; this is too much trust.
6) Backend verification sufficiency: Not sufficient without server-to-server validation and webhook.
7) UPI spoofing/bypass: There is no explicit UPI intent flow in code. Any UPI payment via Razorpay is subject to the same missing webhook and verification gaps.
8) Premium access without payment: No premium logic exists in code. If you plan to gate access client-side using Firestore reads, that is bypassable with a modified app.
9) Database transaction flow/idempotency: No idempotency or state machine; see F4-F6.
10) Storage of payment IDs/order IDs/transaction refs: Stored in transactions docs, but no uniqueness or reconciliation model.
11) HMAC hashing approach: Server HMAC is strong; normalization is present; collision risk is negligible; secret reuse and rotation are the weak points.
12) Env vars and secret exposure: server/.env and serviceAccountKey.json in workspace are high-risk; rotate and remove.
13) Webhook handling security: Not implemented.
14) Duplicate callbacks cause duplicate credits: No dedupe; high risk once webhooks are added; medium risk now.
15) Failed payments becoming successful (or vice versa): Status can flip due to client calls; see F4.
16) Network retry safety: create-order is non-idempotent and verify/fail can race; not safe.
17) Refund handling and reconciliation: Not implemented; no webhook or refund logic.
18) Logs expose PII/secrets: bootstrap_admin prints a reset link; avoid logging sensitive data in production.
19) Release-build readiness: Debug signing is used; keys/secrets present in workspace; adjust before release.
20) Brutal honesty: The payment flow is a prototype and will mis-credit, miss credits, and be un-auditable in production without webhooks and server-side validation.

Minimal-cost production-safe architecture (focused on your current stack)
- Keep Express + Firestore + Razorpay, but add a webhook endpoint that is the source of truth for payment status.
- Change /payment/verify-payment to only confirm that the payment belongs to the order and then mark as pending; finalize only after webhook event payment.captured or order.paid.
- Add server-side Razorpay API verification to check amount/currency/status every time you credit.
- Enforce idempotency using a Firestore transaction and a payment_id registry.

Recommended backend structure (express endpoints)
- POST /payment/create-order: create or reuse a pending order via idempotency key, store intent, return order id and key id.
- POST /payment/verify-payment: validate signature and record payment_id, but do not finalize; trigger a Razorpay fetch for payment status.
- POST /payment/webhook: verify X-Razorpay-Signature using a webhook secret and update transaction status idempotently.
- POST /payment/refund (admin): issue refunds and update status; store refund data.

Recommended payment flow (server-first)
1) Client requests create-order with a clientRequestId.
2) Server creates (or reuses) a transaction with status=created and creates Razorpay order.
3) Client opens Razorpay checkout with order_id.
4) Razorpay sends webhook payment.captured to your server.
5) Server verifies webhook signature, fetches payment/order, validates amount/currency, and sets status=success.
6) Client can poll /payment/status or listen to Firestore for the server-updated status.

Recommended database schema (payments/transactions)
- transactions/{transactionId}
  - userId
  - status: created | pending | success | failed | refunded
  - donationAmountPaise
  - platformFeePaise
  - totalPaidPaise
  - currency
  - razorpay_order_id
  - razorpay_payment_id
  - razorpay_refund_id
  - razorpay_webhook_event_ids: [eventId]
  - createdAt
  - updatedAt
  - statusHistory: [ { status, at, source } ]
  - idempotencyKey
  - hashVersion

- payment_ids/{paymentId}
  - transactionId
  - createdAt

- webhook_events/{eventId}
  - orderId
  - paymentId
  - receivedAt

Proper webhook + verification architecture
- Configure a Razorpay webhook with a dedicated secret.
- Use express.raw() for the webhook route and compute HMAC on the raw body.
- Reject if signature mismatch or eventId already processed.
- Fetch payment/order via Razorpay API and validate amount/currency/status.
- Update transaction status in a Firestore transaction and record eventId.

Proper idempotency implementation
- Accept clientRequestId (UUID) in create-order.
- Store idempotencyKey in transactions and reuse the same order if status is created or pending.
- Use a Firestore transaction to claim paymentId and prevent double crediting.

Proper retry handling
- create-order: safe to retry with the same idempotency key; return the existing order.
- verify-payment: idempotent; if already success with same paymentId, return success.
- webhook: ignore duplicates using webhook event registry.
- Client: add timeouts and backoff; do not send payment-failed if payment was already verified.

Proper secret management
- Remove server/.env from repo and rotate all secrets.
- Use Render env vars or a secret manager; never store serviceAccountKey.json in app directories.
- Use distinct secrets for Razorpay, webhooks, and PII hashing.
- Add secret versioning for PII hashes to allow rotation.

Production deployment checklist (specific to this repo)
- Replace Razorpay test keys with live keys and configure webhook secret.
- Add /payment/webhook endpoint with signature verification.
- Add server-side Razorpay payment/order fetch and amount validation.
- Implement idempotency and status transitions in Firestore transactions.
- Add a release keystore and proper signing for android/app/build.gradle.kts.
- Verify no secrets or service account keys exist in the repo history or current tree.
- Set BACKEND_BASE_URL at build time for release builds.
- Confirm firestore.rules match your final entitlement model.
