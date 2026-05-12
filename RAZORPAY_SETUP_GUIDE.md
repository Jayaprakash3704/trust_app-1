# Razorpay End-to-End Setup Guide (KYC to Live)

This guide covers full Razorpay setup for a Flutter app with Android APK + web app, without publishing to the Play Store. It includes KYC, backend, mobile/web integration, and secure deployment.

## 0) Glossary
- **Test mode**: Razorpay sandbox with test keys.
- **Live mode**: Real payments and settlements.
- **Webhook**: Razorpay server callback for payment status.
- **Order**: Razorpay order object created by your server.
- **Payment**: Razorpay payment object created after user checkout.

## 1) KYC and Merchant Account
1. Create a Razorpay account and start KYC.
2. Provide PAN, bank details, address proof, and GST (if applicable).
3. Complete business verification to enable Live Mode.
4. Set settlement bank account and payout schedule.
5. Confirm legal entity matches your KYC documents.

### 1.1 If Your Account Stays Under Review
Delays are common when Razorpay flags manual verification. Typical reasons:
- Website or app not publicly accessible.
- Missing Privacy Policy, Terms, Refund Policy, or Contact page.
- Business model unclear or mismatch between description and actual app.
- Donation, crowdfunding, or payment aggregation flows.
- Incomplete KYC details.
- Heavy test mode usage before approval.
- High-risk keywords like "trust", "donation", "wallet", "investment", "collect money", "fundraising".

If you are flagged, do this immediately:
1. Publish simple public pages: landing page, Privacy Policy, Terms, Refund Policy, Contact.
2. Make a demo accessible: web build, APK download link, or demo video.
3. Provide demo credentials if login is required.
4. Proactively contact support with a clear explanation of:
   - who pays whom
   - what the money is for
   - where funds settle

Support options:
- support@razorpay.com
- Raise a ticket from the Razorpay dashboard

## 2) Razorpay Dashboard Setup
### 2.1 Create API Keys
- Generate **Test** API keys for development.
- Generate **Live** API keys after KYC approval.

### 2.2 Create Webhook
- Add a webhook URL pointing to your backend.
- Choose events: `payment.captured`, `payment.failed`, and optionally `order.paid`.
- Set a webhook secret and save it securely.

## 3) Secrets and Environment Variables
Never commit secrets to Git. Use environment variables in hosting.

Required backend secrets:
- `RAZORPAY_KEY_ID`
- `RAZORPAY_KEY_SECRET`
- `RAZORPAY_WEBHOOK_SECRET`

For Render or similar hosting, add these in the dashboard environment settings.

## 4) Backend Payment Flow (Server)
This is the secure, production-ready flow:

1. **Create Order**
   - Endpoint: `POST /payment/create-order`
   - Validate amount and user identity.
   - Create a Razorpay order using key secret.
   - Store transaction in database.

2. **Open Checkout (Client)**
   - Client uses `keyId` + `order_id` from create-order response.

3. **Verify Payment (Client Callback)**
   - Endpoint: `POST /payment/verify-payment`
   - Verify signature (HMAC) and fetch payment via Razorpay API.
   - Store `payment_id` and mark status as `pending`.

4. **Webhook (Server Source of Truth)**
   - Endpoint: `POST /payment/webhook`
   - Verify webhook signature against raw body.
   - Fetch payment from Razorpay API and verify amount/currency.
   - Mark status as `success` or `failed` and dedupe by event ID.

### 4.1 Recommended Data Model
transactions/{transactionId}:
- userId
- status: created | pending | success | failed
- donationAmount
- platformFee
- totalPaid
- currency
- razorpay_order_id
- razorpay_payment_id
- createdAt, updatedAt
- idempotencyKey

payment_ids/{paymentId}:
- transactionId
- createdAt

webhook_events/{eventId}:
- orderId
- paymentId
- receivedAt

## 5) Flutter Android (APK) Setup
1. Add dependency: `razorpay_flutter`.
2. Create Razorpay instance and attach listeners.
3. Call `create-order` from backend and open checkout.
4. On success callback, call `verify-payment`.
5. On failure callback, call `payment-failed` and reset UI state.

### 5.1 Release APK (No Play Store)
- Generate a release keystore.
- Sign release APK with your keystore.
- Host APK on your website or file hosting.
- Add in-app version checks if you plan to distribute updates.

## 6) Flutter Web Setup
1. Add Razorpay script in `web/index.html`:
   ```html
   <script src="https://checkout.razorpay.com/v1/checkout.js"></script>
   ```
2. Create order from backend.
3. Open checkout using Razorpay JS (web-only).
4. Send success response to backend `verify-payment`.

## 7) Testing in Test Mode
- Use Razorpay test cards and test UPI.
- Test these cases:
  - success
  - failure
  - cancel
  - app kill
  - network loss
  - webhook retry
- Verify database state matches Razorpay dashboard logs.

## 8) Going Live
1. Switch backend env vars to Live keys.
2. Update webhook to production URL.
3. Run a small live transaction to confirm success.
4. Monitor webhook delivery and settlement reports.

## 9) Security Checklist
- Remove secrets from Git history.
- Do not ship keys in the app.
- Always verify payment amount/currency using Razorpay API or webhook.
- Enforce idempotency for create-order.
- Dedupe payment IDs and webhook event IDs.
- Use HTTPS everywhere.

## 10) Common Errors and Fixes
- **Invalid signature**: Key secret mismatch or raw body not used.
- **Order not found**: Using old order ID or wrong environment.
- **Payment mismatch**: Amount not in paise or wrong currency.

## 11) Suggested Deployment Layout
- Backend on Render or similar.
- Web app on HTTPS hosting.
- Android APK hosted on your website.

---
If you want, I can tailor this guide to your exact backend code and hosting setup, and add step-by-step commands for your environment.
