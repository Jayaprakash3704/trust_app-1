const express = require('express');
const {
  createOrder,
  handleWebhook,
  markPaymentFailed,
  verifyPayment,
} = require('../controllers/paymentController');
const { requireAuth } = require('../middlewares/auth');

const router = express.Router();

router.post('/create-order', requireAuth, createOrder);
router.post('/verify-payment', requireAuth, verifyPayment);
router.post('/payment-failed', requireAuth, markPaymentFailed);
router.post(/^\/webhook(\/.*)?$/, handleWebhook);

module.exports = router;
