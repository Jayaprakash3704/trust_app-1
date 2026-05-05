# Trust Donation App — Implementation TODO (Flutter + Firebase + Node + Render + Razorpay)

This file is the step-by-step build plan for your **locked stack**:

- **Frontend:** Flutter
- **Auth + DB:** Firebase Auth + Firestore
- **Backend:** Node.js (Express)
- **Hosting:** Render
- **Payments:** Razorpay (all payments)

How we’ll use this:
- Treat each section as a checklist.
- When you’re ready, tell me **which Phase/Step to execute** (example: “Do Phase 2B”).
- I’ll implement only what’s in the chosen step, then we move on.

---

## Phase 0 — Confirmed Decisions

> These are the few items your spec implies but doesn’t fully lock. Confirming them prevents rework.

- [x] **Auth login method**
  - [x] Email + password
  - [x] Google sign-in
- [ ] **Admin bootstrap** (still needed)
  - [ ] Provide first admin UID/email to assign custom claim
- [x] **Platform fee rule**
  - [x] Razorpay fee: 2% + 18% GST per successful transaction
  - [x] User pays fee on top of donation (total paid = donation + fee)
- [x] **Money unit convention**
  - [x] Store `donationAmount`, `platformFee`, `totalPaid` as **integers in paise**
- [x] **Profile creation**
  - [x] Admin app creates member profile (Aadhaar/PAN handled by backend hash)
- [ ] **Expense log storage**
  - [ ] Confirm adding a new collection `expenses/` (recommended)
- [x] **Aadhaar/PAN hashing approach**
  - [x] Backend HMAC (pepper secret on server)
- [ ] **Exports**
  - [ ] PDF only
  - [ ] Excel/CSV only
  - [ ] PDF + Excel/CSV

---

## Phase 1 — Firebase Project Setup

### 1A. Create Firebase project
- [ ] Create Firebase project (one per environment; start with `dev`)
- [ ] Enable **Firestore** in production mode
- [ ] Enable **Firebase Authentication**
  - [ ] Turn on the chosen provider (Email/Password or Phone)

### 1B. Register Flutter apps in Firebase
- [ ] Android app
  - [ ] Confirm Android `applicationId` (package name) you want to use
  - [ ] Download `google-services.json` → place into `android/app/`
- [ ] iOS app (if you will build iOS)
  - [ ] Confirm iOS bundle id
  - [ ] Download `GoogleService-Info.plist` → place into `ios/Runner/`

### 1C. Generate Flutter Firebase config
- [ ] Install FlutterFire CLI (one-time)
  - [ ] `dart pub global activate flutterfire_cli`
- [ ] Configure
  - [ ] `flutterfire configure`
- [ ] Verify app runs with `Firebase.initializeApp()`

### 1D. Backend service account (for Admin SDK)
- [ ] Create Firebase service account key (JSON)
- [ ] Store it in Render as an env var (recommended: `FIREBASE_SERVICE_ACCOUNT_JSON`)
- [ ] Decide: also store `FIREBASE_PROJECT_ID` explicitly

---

## Phase 2 — Firestore Data Model (Final Collections)

> Your final collections: `users/`, `transactions/`, `reports/`.

### 2A. `users/{userId}` document
- [ ] Fields (as per spec)
  - [ ] `name`
  - [ ] `phone`
  - [ ] `address`
  - [ ] `role` (`admin` | `user`) **(UI field; do NOT trust for security rules)**
  - [ ] `aadhaar_last4`
  - [ ] `aadhaar_hash`
  - [ ] `pan_last4`
  - [ ] `pan_hash`
  - [ ] `createdAt`

### 2B. `transactions/{transactionId}` document
- [ ] Fields (as per spec)
  - [ ] `userId`
  - [ ] `donationAmount`
  - [ ] `platformFee`
  - [ ] `totalPaid`
  - [ ] `razorpay_order_id`
  - [ ] `razorpay_payment_id`
  - [ ] `status` (`created` | `success` | `failed`)
  - [ ] `year`
  - [ ] `month`
  - [ ] `timestamp`

### 2C. `reports/{reportId}` document
- [ ] Fields (as per spec)
  - [ ] `year`
  - [ ] `totalRevenue`
  - [ ] `totalUsers`
  - [ ] `generatedAt`

### 2D. Indexes (needed for filters)
- [ ] Plan composite indexes for common admin queries
  - [ ] `transactions` by `year + month + timestamp`
  - [ ] `transactions` by `userId + timestamp`
  - [ ] `transactions` by `status + timestamp`

---

## Phase 3 — Security (Non‑negotiable)

### 3A. AuthZ strategy (recommended)
- [ ] Use **Firebase Auth custom claims** for roles
  - [ ] `request.auth.token.role == 'admin'` for admin privileges
- [ ] Keep Firestore `users.role` as display-only (UI), but **rules must rely on custom claims**

### 3B. Firestore rules
- [ ] `users/{userId}`
  - [ ] User can read own doc
  - [ ] User can update safe profile fields (name/phone/address) only
  - [ ] Admin can read all
  - [ ] Prevent client updates to sensitive fields (`role`, hashes)
- [ ] `transactions/{transactionId}`
  - [ ] User can read only where `resource.data.userId == request.auth.uid`
  - [ ] Admin can read all
  - [ ] Client writes: deny (backend writes via Admin SDK)
- [ ] `reports/{reportId}`
  - [ ] Admin read/write only
  - [ ] Users: deny

### 3C. Aadhaar/PAN handling
- [ ] Store **only** `*_hash` and `*_last4`
- [ ] Ensure raw values are never logged or stored

---

## Phase 4 — Node.js Backend (Express) + Razorpay

Target folder structure (as you specified):

- [ ] `server/index.js`
- [ ] `server/routes/payment.js`
- [ ] `server/controllers/paymentController.js`
- [ ] `server/utils/razorpay.js`

### 4A. Backend bootstrap
- [ ] Initialize Node project inside `server/`
  - [ ] `npm init -y`
- [ ] Install dependencies (suggested)
  - [ ] `express`, `cors`, `dotenv`, `razorpay`, `firebase-admin`
  - [ ] `helmet`, `express-rate-limit`
  - [ ] validation: `zod` (or `joi`)

### 4B. Environment variables (Render)
- [ ] `RAZORPAY_KEY_ID`
- [ ] `RAZORPAY_KEY_SECRET` (NEVER in Flutter)
- [ ] `FIREBASE_SERVICE_ACCOUNT_JSON`
- [ ] `ALLOWED_ORIGINS` (optional)
- [ ] `PORT`

### 4C. Auth middleware (recommended)
- [ ] Require Firebase ID token for payment endpoints
  - [ ] Read `Authorization: Bearer <idToken>`
  - [ ] Verify using Firebase Admin SDK

### 4D. Implement endpoints

#### POST `/create-order`
- [ ] Input: `donationAmount`, `platformFee`
- [ ] Compute: `totalPaid = donationAmount + platformFee`
- [ ] Create Razorpay order (amount in paise)
- [ ] Create Firestore `transactions` doc with:
  - [ ] `status: 'created'`
  - [ ] `razorpay_order_id`
  - [ ] `timestamp`, `year`, `month`
- [ ] Return: `transactionId`, `razorpay_order_id`, `amount`, `currency`, `keyId`

#### POST `/verify-payment`
- [ ] Input: `transactionId`, `razorpay_order_id`, `razorpay_payment_id`, `razorpay_signature`
- [ ] Verify Razorpay signature on backend
- [ ] Update Firestore transaction:
  - [ ] `status: 'success'` or `failed`
  - [ ] set `razorpay_payment_id`

### 4E. Cold-start UX support
- [ ] Add GET `/health` endpoint
- [ ] Ensure `/create-order` is fast + idempotent

---

## Phase 5 — Deploy Backend on Render

- [ ] Create Render Web Service
  - [ ] Root directory: `server/`
  - [ ] Build: `npm ci` (or `npm install`)
  - [ ] Start: `node index.js`
- [ ] Add environment variables (from Phase 4B)
- [ ] Verify health check: `GET /health`
- [ ] Optional: set up uptime ping (UptimeRobot) to reduce cold start

---

## Phase 6 — Flutter App (Clean Structure + Core Services)

Target structure (as you specified):

- [ ] `lib/core/constants/`
- [ ] `lib/core/utils/`
- [ ] `lib/services/auth_service.dart`
- [ ] `lib/services/payment_service.dart`
- [ ] `lib/services/firestore_service.dart`
- [ ] `lib/features/auth/`
- [ ] `lib/features/admin/dashboard/`
- [ ] `lib/features/admin/members/`
- [ ] `lib/features/admin/reports/`
- [ ] `lib/features/user/dashboard/`
- [ ] `lib/features/user/payment/`
- [ ] `lib/features/user/history/`

### 6A. Add Flutter dependencies
- [ ] Firebase
  - [ ] `firebase_core`, `firebase_auth`, `cloud_firestore`
- [ ] Backend API client
  - [ ] `http`
- [ ] Razorpay Checkout
  - [ ] `razorpay_flutter`
- [ ] Export/share (depends on Phase 0)
  - [ ] PDF: `pdf`, `printing`
  - [ ] Share: `share_plus`
  - [ ] Excel/CSV: `excel` (or CSV approach)

### 6B. App bootstrap
- [ ] Initialize Firebase in `main.dart`
- [ ] Auth state handling
  - [ ] If not logged in → Auth screens
  - [ ] If logged in → fetch user profile → route by role

### 6C. Role-based routing
- [ ] Admin → Admin shell
- [ ] User → User shell

---

## Phase 7 — Payment Flow (Razorpay End-to-End)

### 7A. Payment screen UX (cold start handled)
- [ ] When payment screen opens:
  - [ ] pre-call backend `POST /create-order`
  - [ ] show loading state while order is created
- [ ] Then open Razorpay checkout using returned `razorpay_order_id`

### 7B. Success path
- [ ] On Razorpay success callback:
  - [ ] call backend `POST /verify-payment`
  - [ ] backend verifies signature + marks transaction success in Firestore
- [ ] Show success UI + navigate to history

### 7C. Failure/cancel path
- [ ] Mark transaction failed (backend or client-triggered endpoint)
- [ ] Show retry option

---

## Phase 8 — Admin Features (Clean Version)

### 8A. Dashboard
- [ ] Total revenue summary
- [ ] Filters: monthly, yearly, custom range

### 8B. Member creation & management
- [ ] Create/update member profile in `users/`
- [ ] Aadhaar/PAN: store `hash + last4` only
- [ ] (If using email/password auth) implement “first-time password setup”
  - [ ] Decide whether admin creates accounts (requires backend Admin SDK)
  - [ ] Or users self-register then admin approves role

### 8C. Transactions
- [ ] List all transactions
- [ ] Filter + export

### 8D. Expense log
- [ ] Implement expense log storage (depends on Phase 0 decision)

### 8E. Reports
- [ ] Current year
- [ ] Custom year
- [ ] Individual user report
- [ ] Export PDF/Excel + share

---

## Phase 9 — User Features (Clean Version)

- [ ] Login (Firebase Auth)
- [ ] First-time password setup (if using email/password)
- [ ] Dashboard: total donated
- [ ] Payment screen
- [ ] Transaction history
- [ ] Optional due reminders

---

## Phase 10 — QA + Hardening

- [ ] Backend
  - [ ] Verify signature tests
  - [ ] Input validation + rate limiting
  - [ ] Ensure no secrets logged
- [ ] Firebase
  - [ ] Rules test with admin vs user
  - [ ] Confirm least privilege
- [ ] Flutter
  - [ ] Manual payment test matrix: success / failure / cancel / network retry
  - [ ] Verify cold-start path: pre-call order + loading UI

---

## “Ready to execute” next step

Pick one and tell me:
- “Do Phase 1A–1D” (Firebase setup guidance)
- “Do Phase 4A–4E” (create backend scaffold + endpoints)
- “Do Phase 6A–6C” (Flutter Firebase integration + routing skeleton)

If you answer Phase 0 decisions first, we can implement without rework.