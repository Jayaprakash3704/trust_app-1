const cors = require('cors');
const dotenv = require('dotenv');
const express = require('express');
const helmet = require('helmet');
const path = require('path');
const rateLimit = require('express-rate-limit');
const adminRoutes = require('./routes/admin');
const paymentRoutes = require('./routes/payment');
const { initFirebaseAdmin } = require('./utils/firebase');

dotenv.config();
initFirebaseAdmin();

const app = express();
const serverStartedAt = new Date();
const adminUiPath = path.join(__dirname, 'admin-ui');
const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map((origin) => origin.trim()).filter(Boolean)
  : [];

app.use(
  helmet({
    contentSecurityPolicy: {
      useDefaults: true,
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: ["'self'", 'https://www.gstatic.com'],
        styleSrc: ["'self'", 'https://fonts.googleapis.com'],
        fontSrc: ['https://fonts.gstatic.com'],
        imgSrc: ["'self'", 'data:'],
        connectSrc: [
          "'self'",
          'https://firebase.googleapis.com',
          'https://identitytoolkit.googleapis.com',
          'https://securetoken.googleapis.com',
          'https://www.googleapis.com',
        ],
        frameAncestors: ["'none'"],
        objectSrc: ["'none'"],
        baseUri: ["'self'"],
      },
    },
  })
);
app.use(cors(allowedOrigins.length ? { origin: allowedOrigins } : {}));
app.use('/payment/webhook', express.raw({ type: 'application/json' }));
app.use(express.json({ limit: '1mb' }));

app.use(
  rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 300,
  })
);

app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    startedAt: serverStartedAt.toISOString(),
    uptimeSeconds: Math.floor(process.uptime()),
  });
});

app.use('/admin', express.static(adminUiPath, { index: 'index.html' }));

app.get('/', (req, res) => {
  res.json({
    status: 'ok',
    message: 'Trust App API is running.',
    endpoints: ['/health', '/payment', '/admin'],
  });
});

app.use('/payment', paymentRoutes);
app.use('/admin', adminRoutes);

const port = Number(process.env.PORT) || 8080;
app.listen(port, () => {
  // eslint-disable-next-line no-console
  console.log(`Server listening on ${port}`);
});
