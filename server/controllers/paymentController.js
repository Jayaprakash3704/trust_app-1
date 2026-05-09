const crypto = require('crypto');
const { z } = require('zod');
const { admin, getDb } = require('../utils/firebase');
const { getRazorpayClient } = require('../utils/razorpay');

const STATUS = {
  CREATED: 'created',
  PENDING: 'pending',
  SUCCESS: 'success',
  FAILED: 'failed',
};

const CURRENCY = 'INR';

const createOrderSchema = z.object({
  donationAmount: z.number().int().positive(),
  clientRequestId: z.string().uuid().optional(),
});

const verifyPaymentSchema = z.object({
  transactionId: z.string().min(1),
  razorpay_order_id: z.string().min(1),
  razorpay_payment_id: z.string().min(1),
  razorpay_signature: z.string().min(1),
});

const paymentFailedSchema = z.object({
  transactionId: z.string().min(1),
});

function computePlatformFee(donationAmount) {
  return Math.ceil((donationAmount * 236) / 10000);
}

function getCurrentYearMonth() {
  const now = new Date();
  return {
    year: now.getFullYear(),
    month: now.getMonth() + 1,
  };
}

function timingSafeEqualHex(expected, provided) {
  if (expected.length !== provided.length) {
    return false;
  }
  return crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(provided));
}

function buildOrderResponse(transactionId, transaction) {
  return {
    transactionId,
    razorpay_order_id: transaction.razorpay_order_id,
    amount: transaction.totalPaid,
    currency: transaction.currency || CURRENCY,
    keyId: process.env.RAZORPAY_KEY_ID,
    platformFee: transaction.platformFee,
    totalPaid: transaction.totalPaid,
  };
}

function validatePaymentAgainstTransaction(payment, transaction, razorpayOrderId) {
  if (!payment) {
    throw new Error('Payment not found');
  }
  if (payment.order_id !== razorpayOrderId) {
    throw new Error('Order ID mismatch');
  }
  if ((transaction.currency || CURRENCY) !== payment.currency) {
    throw new Error('Currency mismatch');
  }
  if (transaction.totalPaid !== payment.amount) {
    throw new Error('Amount mismatch');
  }
  if (payment.status !== 'captured') {
    throw new Error('Payment not captured');
  }
}

function getRawBody(req) {
  if (Buffer.isBuffer(req.body)) {
    return req.body;
  }
  if (typeof req.body === 'string') {
    return Buffer.from(req.body);
  }
  return Buffer.from(JSON.stringify(req.body ?? {}));
}

function verifyRazorpaySignature(payload, secret, signature) {
  const expected = crypto.createHmac('sha256', secret).update(payload).digest('hex');
  return timingSafeEqualHex(expected, signature);
}

async function findExistingTransaction(db, userId, clientRequestId) {
  const snapshot = await db
    .collection('transactions')
    .where('userId', '==', userId)
    .where('idempotencyKey', '==', clientRequestId)
    .limit(1)
    .get();

  if (snapshot.empty) {
    return null;
  }

  const doc = snapshot.docs[0];
  return { id: doc.id, data: doc.data() };
}

async function createOrder(req, res) {
  const parsed = createOrderSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: 'Invalid donation amount' });
  }

  const { donationAmount, clientRequestId } = parsed.data;
  const platformFee = computePlatformFee(donationAmount);
  const totalPaid = donationAmount + platformFee;
  const { year, month } = getCurrentYearMonth();

  const db = getDb();

  if (clientRequestId) {
    const existing = await findExistingTransaction(
      db,
      req.user.uid,
      clientRequestId,
    );
    if (existing) {
      if (existing.data.donationAmount !== donationAmount) {
        return res.status(409).json({
          error: 'Idempotency key reuse with different amount',
        });
      }
      if (existing.data.status === STATUS.SUCCESS) {
        return res.status(409).json({ error: 'Payment already completed' });
      }
      if (existing.data.status === STATUS.FAILED) {
        return res.status(409).json({ error: 'Payment already failed' });
      }
      return res.json(buildOrderResponse(existing.id, existing.data));
    }
  }

  let intentRef = null;
  if (clientRequestId) {
    intentRef = db
      .collection('payment_idempotency')
      .doc(`${req.user.uid}_${clientRequestId}`);
    try {
      await intentRef.create({
        userId: req.user.uid,
        donationAmount,
        status: 'initializing',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error) {
      if (error.code === 6 || error.code === 'already-exists') {
        const intentSnap = await intentRef.get();
        const intent = intentSnap.exists ? intentSnap.data() : null;
        if (intent?.transactionId) {
          const txSnap = await db
            .collection('transactions')
            .doc(intent.transactionId)
            .get();
          if (txSnap.exists) {
            return res.json(buildOrderResponse(txSnap.id, txSnap.data()));
          }
        }
        return res
          .status(409)
          .json({ error: 'Payment initialization in progress. Please retry.' });
      }
      throw error;
    }
  }

  const transactionRef = db.collection('transactions').doc();
  const transactionId = transactionRef.id;

  const razorpay = getRazorpayClient();
  let order;
  try {
    order = await razorpay.orders.create({
      amount: totalPaid,
      currency: CURRENCY,
      receipt: transactionId,
      notes: {
        userId: req.user.uid,
        clientRequestId: clientRequestId ?? '',
      },
    });
  } catch (error) {
    if (intentRef) {
      await intentRef.delete().catch(() => {});
    }
    throw error;
  }

  try {
    await transactionRef.set({
      userId: req.user.uid,
      donationAmount,
      platformFee,
      totalPaid,
      currency: CURRENCY,
      razorpay_order_id: order.id,
      razorpay_payment_id: null,
      status: STATUS.CREATED,
      idempotencyKey: clientRequestId ?? null,
      year,
      month,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    if (intentRef) {
      await intentRef.delete().catch(() => {});
    }
    throw error;
  }

  if (intentRef) {
    await intentRef.set(
      {
        status: 'ready',
        transactionId,
        razorpay_order_id: order.id,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }

  return res.json({
    transactionId,
    razorpay_order_id: order.id,
    amount: order.amount,
    currency: order.currency,
    keyId: process.env.RAZORPAY_KEY_ID,
    platformFee,
    totalPaid,
  });
}

async function verifyPayment(req, res) {
  const parsed = verifyPaymentSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: 'Invalid payment verification payload' });
  }

  const {
    transactionId,
    razorpay_order_id,
    razorpay_payment_id,
    razorpay_signature,
  } = parsed.data;

  const db = getDb();
  const transactionRef = db.collection('transactions').doc(transactionId);
  const transactionSnap = await transactionRef.get();

  if (!transactionSnap.exists) {
    return res.status(404).json({ error: 'Transaction not found' });
  }

  const transaction = transactionSnap.data();
  if (transaction.userId !== req.user.uid && req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Forbidden' });
  }

  if (transaction.razorpay_order_id !== razorpay_order_id) {
    return res.status(400).json({ error: 'Order ID mismatch' });
  }

  if (transaction.status === STATUS.SUCCESS) {
    return res.json({ status: STATUS.SUCCESS });
  }

  if (transaction.status === STATUS.FAILED) {
    return res.status(409).json({ error: 'Payment already failed' });
  }

  if (
    transaction.razorpay_payment_id &&
    transaction.razorpay_payment_id !== razorpay_payment_id
  ) {
    return res.status(409).json({ error: 'Payment ID mismatch' });
  }

  const keySecret = process.env.RAZORPAY_KEY_SECRET;
  if (!keySecret) {
    return res.status(500).json({ error: 'Razorpay secret missing' });
  }

  const signaturePayload = `${razorpay_order_id}|${razorpay_payment_id}`;
  const signaturesMatch = verifyRazorpaySignature(
    signaturePayload,
    keySecret,
    razorpay_signature,
  );

  if (!signaturesMatch) {
    return res.status(400).json({ error: 'Invalid signature' });
  }

  const razorpay = getRazorpayClient();
  let payment;
  try {
    payment = await razorpay.payments.fetch(razorpay_payment_id);
  } catch (error) {
    return res.status(502).json({ error: 'Unable to verify payment with Razorpay' });
  }

  try {
    validatePaymentAgainstTransaction(payment, transaction, razorpay_order_id);
  } catch (error) {
    return res.status(400).json({
      error: error.message || 'Payment verification failed',
    });
  }

  try {
    await db.runTransaction(async (tx) => {
      const freshSnap = await tx.get(transactionRef);
      const current = freshSnap.data();
      if (!current) {
        return;
      }

      if (current.status === STATUS.SUCCESS) {
        return;
      }

      if (current.status === STATUS.FAILED) {
        throw new Error('Payment already failed');
      }

      const paymentRef = db.collection('payment_ids').doc(razorpay_payment_id);
      const paymentSnap = await tx.get(paymentRef);
      if (paymentSnap.exists) {
        const existing = paymentSnap.data();
        if (existing?.transactionId !== transactionId) {
          throw new Error('Payment ID already used');
        }
      } else {
        tx.set(paymentRef, {
          transactionId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      tx.update(transactionRef, {
        status: STATUS.PENDING,
        razorpay_payment_id,
        paymentStatus: payment.status,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        statusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
  } catch (error) {
    return res.status(409).json({
      error: error.message || 'Payment already processed',
    });
  }

  return res.json({ status: STATUS.PENDING });
}

async function markPaymentFailed(req, res) {
  const parsed = paymentFailedSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: 'Invalid payload' });
  }

  const { transactionId } = parsed.data;
  const db = getDb();
  const transactionRef = db.collection('transactions').doc(transactionId);
  const transactionSnap = await transactionRef.get();

  if (!transactionSnap.exists) {
    return res.status(404).json({ error: 'Transaction not found' });
  }

  const transaction = transactionSnap.data();
  if (transaction.userId !== req.user.uid && req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Forbidden' });
  }

  await transactionRef.update({
    clientStatus: STATUS.FAILED,
    clientFailedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return res.json({ status: transaction.status || STATUS.CREATED });
}

async function handleWebhook(req, res) {
  const signature = req.headers['x-razorpay-signature'];
  const webhookSecret = process.env.RAZORPAY_WEBHOOK_SECRET;
  if (!webhookSecret) {
    return res.status(500).json({ error: 'Razorpay webhook secret missing' });
  }

  if (!signature || typeof signature !== 'string') {
    return res.status(400).json({ error: 'Missing webhook signature' });
  }

  const rawBody = getRawBody(req);
  const signatureValid = verifyRazorpaySignature(
    rawBody,
    webhookSecret,
    signature,
  );

  if (!signatureValid) {
    return res.status(400).json({ error: 'Invalid webhook signature' });
  }

  let payload;
  try {
    payload = JSON.parse(rawBody.toString('utf8'));
  } catch (error) {
    return res.status(400).json({ error: 'Invalid webhook payload' });
  }

  const eventId = payload?.id;
  const eventType = payload?.event;
  const paymentEntity = payload?.payload?.payment?.entity;
  const orderEntity = payload?.payload?.order?.entity;
  const orderId = paymentEntity?.order_id || orderEntity?.id;
  const paymentId = paymentEntity?.id;

  if (!eventId || !eventType) {
    return res.status(400).json({ error: 'Invalid webhook payload' });
  }

  const db = getDb();
  const eventRef = db.collection('webhook_events').doc(eventId);
  const existingEvent = await eventRef.get();
  if (existingEvent.exists) {
    return res.json({ status: 'ignored' });
  }

  if (!orderId) {
    await eventRef.set({
      event: eventType,
      receivedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return res.json({ status: 'ignored' });
  }

  const transactionQuery = db
    .collection('transactions')
    .where('razorpay_order_id', '==', orderId)
    .limit(1);
  const transactionSnap = await transactionQuery.get();
  if (transactionSnap.empty) {
    await eventRef.set({
      event: eventType,
      orderId,
      paymentId: paymentId ?? null,
      receivedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return res.json({ status: 'ignored' });
  }

  const transactionDoc = transactionSnap.docs[0];
  const transaction = transactionDoc.data();

  if (eventType === 'payment.captured') {
    if (!paymentId) {
      await eventRef.set({
        event: eventType,
        orderId,
        receivedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return res.json({ status: 'ignored' });
    }

    const razorpay = getRazorpayClient();
    let payment;
    try {
      payment = await razorpay.payments.fetch(paymentId);
    } catch (error) {
      return res
        .status(502)
        .json({ error: 'Unable to verify payment with Razorpay' });
    }

    try {
      validatePaymentAgainstTransaction(payment, transaction, orderId);
    } catch (error) {
      return res.status(400).json({
        error: error.message || 'Payment verification failed',
      });
    }

    try {
      await db.runTransaction(async (tx) => {
        const eventSnap = await tx.get(eventRef);
        if (eventSnap.exists) {
          return;
        }

        const currentSnap = await tx.get(transactionDoc.ref);
        const current = currentSnap.data();
        if (!current) {
          return;
        }

        if (current.status === STATUS.SUCCESS) {
          tx.set(eventRef, {
            event: eventType,
            orderId,
            paymentId,
            receivedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          return;
        }

        if (current.status === STATUS.FAILED) {
          tx.set(eventRef, {
            event: eventType,
            orderId,
            paymentId,
            receivedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          return;
        }

        const paymentRef = db.collection('payment_ids').doc(paymentId);
        const paymentSnap = await tx.get(paymentRef);
        if (paymentSnap.exists) {
          const existing = paymentSnap.data();
          if (existing?.transactionId !== transactionDoc.id) {
            throw new Error('Payment ID already used');
          }
        } else {
          tx.set(paymentRef, {
            transactionId: transactionDoc.id,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        tx.set(eventRef, {
          event: eventType,
          orderId,
          paymentId,
          receivedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        tx.update(transactionDoc.ref, {
          status: STATUS.SUCCESS,
          razorpay_payment_id: paymentId,
          paymentStatus: payment.status,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          statusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
    } catch (error) {
      return res.status(409).json({
        error: error.message || 'Payment already processed',
      });
    }

    return res.json({ status: STATUS.SUCCESS });
  }

  if (eventType === 'payment.failed') {
    await db.runTransaction(async (tx) => {
      const eventSnap = await tx.get(eventRef);
      if (eventSnap.exists) {
        return;
      }

      const currentSnap = await tx.get(transactionDoc.ref);
      const current = currentSnap.data();
      if (!current) {
        return;
      }

      if (current.status === STATUS.SUCCESS) {
        tx.set(eventRef, {
          event: eventType,
          orderId,
          paymentId: paymentId ?? null,
          receivedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
      }

      tx.set(eventRef, {
        event: eventType,
        orderId,
        paymentId: paymentId ?? null,
        receivedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      tx.update(transactionDoc.ref, {
        status: STATUS.FAILED,
        razorpay_payment_id: paymentId ?? current.razorpay_payment_id ?? null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        statusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    return res.json({ status: STATUS.FAILED });
  }

  await eventRef.set({
    event: eventType,
    orderId,
    paymentId: paymentId ?? null,
    receivedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return res.json({ status: 'ignored' });
}

module.exports = {
  createOrder,
  handleWebhook,
  markPaymentFailed,
  verifyPayment,
};
