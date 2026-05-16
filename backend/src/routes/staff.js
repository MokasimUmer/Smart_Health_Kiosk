const staffCtrl = require('../controllers/staffController');
const { authenticate } = require('../middleware/auth');

function hospitalStaff(req, res, next) {
  if (req.user.role !== 'provider' || !req.user.hospitalId) {
    return res.status(403).json({ error: 'Hospital staff access required' });
  }
  next();
}

function hospitalAdmin(req, res, next) {
  if (req.user.role !== 'provider' || !req.user.hospitalId) {
    return res.status(403).json({ error: 'Hospital staff access required' });
  }
  const pr = req.user.providerRole || 'hospital_admin';
  if (pr !== 'hospital_admin') {
    return res.status(403).json({ error: 'Hospital administrator access required' });
  }
  next();
}

const router = require('express').Router();

router.use(authenticate, hospitalStaff);

router.get('/doctors', hospitalAdmin, staffCtrl.listHospitalDoctors);
router.get('/availability/for-slot', hospitalAdmin, staffCtrl.doctorsFreeAt);

router.get('/availability/mine', staffCtrl.getMyAvailability);
router.put('/availability/mine', staffCtrl.putMyAvailability);

module.exports = router;
