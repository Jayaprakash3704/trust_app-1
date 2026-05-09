const express = require('express');
const {
	createUser,
	updateUser,
	createResetLink,
} = require('../controllers/adminController');
const { requireAdmin, requireAuth } = require('../middlewares/auth');

const router = express.Router();

router.post('/create-user', requireAuth, requireAdmin, createUser);
router.post('/update-user', requireAuth, requireAdmin, updateUser);
router.post('/reset-link', requireAuth, requireAdmin, createResetLink);

module.exports = router;
