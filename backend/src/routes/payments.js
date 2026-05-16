const router = require('express').Router();
const ctrl = require('../controllers/paymentController');
const { authenticate, authorize } = require('../middleware/auth');

router.get('/config', authenticate, authorize('patient'), ctrl.getPaymentConfig);
router.post('/subscription/init', authenticate, authorize('patient'), ctrl.initSubscriptionPayment);
router.post('/appointment/init', authenticate, authorize('patient'), ctrl.initAppointmentPayment);
router.get('/verify/:txRef', authenticate, authorize('patient'), ctrl.verifyPayment);

router.post('/chapa/webhook', ctrl.chapaWebhook);
router.get('/chapa/webhook', ctrl.chapaWebhook);
router.get('/chapa/return', ctrl.chapaReturn);

module.exports = router;
