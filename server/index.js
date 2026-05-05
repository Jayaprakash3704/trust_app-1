const cors = require('cors');
const dotenv = require('dotenv');
const express = require('express');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const adminRoutes = require('./routes/admin');
const paymentRoutes = require('./routes/payment');
const { initFirebaseAdmin } = require('./utils/firebase');

dotenv.config();
initFirebaseAdmin();

const app = express();
const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map((origin) => origin.trim()).filter(Boolean)
  : [];

app.use(helmet());
app.use(cors(allowedOrigins.length ? { origin: allowedOrigins } : {}));
app.use(express.json({ limit: '1mb' }));

app.use(
  rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 300,
  })
);

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.use('/payment', paymentRoutes);
app.use('/admin', adminRoutes);

const port = Number(process.env.PORT) || 8080;
app.listen(port, () => {
  // eslint-disable-next-line no-console
  console.log(`Server listening on ${port}`);
});
