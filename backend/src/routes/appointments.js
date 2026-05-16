const router = require('express').Router();
const ctrl = require('../controllers/appointmentController');
const { authenticate, authorize } = require('../middleware/auth');
router.post('/', authenticate, authorize('patient'), (_req, res) => {
  res.status(410).json({
    error: 'Receipt upload is no longer supported. Pay with Chapa via POST /api/payments/appointment/init',
  });
});
router.get('/mine', authenticate, authorize('patient'), ctrl.getMyAppointments);
router.get('/hospital', authenticate, authorize('provider'), ctrl.getHospitalAppointments);
router.patch('/:id/review', authenticate, authorize('provider'), ctrl.reviewAppointment);
router.patch('/:id/assign', authenticate, authorize('provider'), ctrl.reassignAppointment);
router.get('/hospital/patients', authenticate, authorize('provider'), ctrl.getHospitalPatients);

module.exports = router;
