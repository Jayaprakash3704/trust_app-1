const crypto = require('crypto');
const { z } = require('zod');
const { admin, getDb } = require('../utils/firebase');
const { getRazorpayClient } = require('../utils/razorpay');

const createOrderSchema = z.object({
  donationAmount: z.number().int().positive(),
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

async function createOrder(req, res) {
  const parsed = createOrderSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: 'Invalid donation amount' });
  }

  const { donationAmount } = parsed.data;
  const platformFee = computePlatformFee(donationAmount);
  const totalPaid = donationAmount + platformFee;
  const { year, month } = getCurrentYearMonth();

  const db = getDb();
  const transactionRef = db.collection('transactions').doc();
  const transactionId = transactionRef.id;

  const razorpay = getRazorpayClient();
  const order = await razorpay.orders.create({
    amount: totalPaid,
    currency: 'INR',
    receipt: transactionId,
    notes: {
      userId: req.user.uid,
    },
  });

  await transactionRef.set({
    userId: req.user.uid,
    donationAmount,
    platformFee,
    totalPaid,
    razorpay_order_id: order.id,
    razorpay_payment_id: null,
    status: 'created',
    year,
    month,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

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

  const keySecret = process.env.RAZORPAY_KEY_SECRET;
  if (!keySecret) {
    return res.status(500).json({ error: 'Razorpay secret missing' });
  }

  const expectedSignature = crypto
    .createHmac('sha256', keySecret)
    .update(`${razorpay_order_id}|${razorpay_payment_id}`)
    .digest('hex');

  const signaturesMatch =
    expectedSignature.length === razorpay_signature.length &&
    crypto.timingSafeEqual(
      Buffer.from(expectedSignature),
      Buffer.from(razorpay_signature)
    );

  if (!signaturesMatch) {
    await transactionRef.update({
      status: 'failed',
    });

    return res.status(400).json({ error: 'Invalid signature' });
  }

  await transactionRef.update({
    status: 'success',
    razorpay_payment_id,
  });

  return res.json({ status: 'success' });
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
    status: 'failed',
  });

  return res.json({ status: 'failed' });
}

module.exports = {
  createOrder,
  markPaymentFailed,
  verifyPayment,
};
