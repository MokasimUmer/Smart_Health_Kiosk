const router = require('express').Router();
const ctrl = require('../controllers/subscriptionController');
const { authenticate, authorize } = require('../middleware/auth');
router.post('/', authenticate, authorize('patient'), (_req, res) => {
  res.status(410).json({
    error: 'Receipt upload is no longer supported. Pay with Chapa via POST /api/payments/subscription/init',
  });
});
router.get('/mine', authenticate, authorize('patient'), ctrl.getMySubscription);
router.get('/pending', authenticate, authorize('super_admin'), ctrl.getPendingSubscriptions);
router.get('/', authenticate, authorize('super_admin'), ctrl.getAllSubscriptions);
router.patch('/:id/review', authenticate, authorize('super_admin'), ctrl.reviewSubscription);

module.exports = router;
