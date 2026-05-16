const { UserAccount, DoctorAvailability } = require('../models');
const { listDoctorsFreeAt, loadSlotsForHospital, isDoctorFreeAt } = require('../utils/doctorAvailability');

function providerRole(req) {
  return req.user.providerRole || 'hospital_admin';
}

/** GET /staff/doctors — admins: all doctors in hospital */
exports.listHospitalDoctors = async (req, res) => {
  try {
    const hospitalId = req.user.hospitalId;
    const doctors = await UserAccount.find({
      hospitalId,
      role: 'provider',
      providerRole: 'doctor',
      isActive: true,
    })
      .select('name username')
      .sort({ name: 1 })
      .lean();

    const slots = await loadSlotsForHospital(hospitalId);
    const withSlots = doctors.map((d) => ({
      ...d,
      availability: slots.filter((s) => s.doctorId.toString() === d._id.toString()),
    }));

    res.json({ doctors: withSlots });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

/** GET /staff/availability/for-slot?at=ISO — admin: doctors free at that instant */
exports.doctorsFreeAt = async (req, res) => {
  try {
    const hospitalId = req.user.hospitalId;
    const atRaw = req.query.at;
    if (!atRaw || Number.isNaN(new Date(atRaw).getTime())) {
      return res.status(400).json({ error: 'Query "at" must be a valid ISO datetime' });
    }
    const at = new Date(atRaw);
    const doctors = await listDoctorsFreeAt(hospitalId, at);
    res.json({ doctors, at: at.toISOString() });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

/** GET /staff/availability/mine — doctor: own weekly template */
exports.getMyAvailability = async (req, res) => {
  try {
    if (providerRole(req) !== 'doctor') {
      return res.status(403).json({ error: 'Only staff doctors manage weekly availability here' });
    }
    const hospitalId = req.user.hospitalId;
    const slots = await DoctorAvailability.find({
      hospitalId,
      doctorId: req.user.id,
    })
      .sort({ dayOfWeek: 1, startTime: 1 })
      .lean();
    res.json({ slots });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

/** PUT /staff/availability/mine — doctor: replace all slots */
exports.putMyAvailability = async (req, res) => {
  try {
    if (providerRole(req) !== 'doctor') {
      return res.status(403).json({ error: 'Only staff doctors can update availability' });
    }
    const hospitalId = req.user.hospitalId;
    const { slots } = req.body;
    if (!Array.isArray(slots)) {
      return res.status(400).json({ error: 'Body must include slots: array' });
    }

    const cleaned = [];
    for (const s of slots) {
      const dow = Number(s.dayOfWeek);
      const st = String(s.startTime || '').trim();
      const en = String(s.endTime || '').trim();
      if (Number.isNaN(dow) || dow < 0 || dow > 6) continue;
      if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(st) || !/^([01]\d|2[0-3]):[0-5]\d$/.test(en)) continue;
      cleaned.push({ hospitalId, doctorId: req.user.id, dayOfWeek: dow, startTime: st, endTime: en });
    }

    await DoctorAvailability.deleteMany({ hospitalId, doctorId: req.user.id });
    if (cleaned.length) await DoctorAvailability.insertMany(cleaned);

    const saved = await DoctorAvailability.find({ hospitalId, doctorId: req.user.id })
      .sort({ dayOfWeek: 1, startTime: 1 })
      .lean();
    res.json({ slots: saved });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

/** Used by appointment approval — verify doctor belongs to hospital and is free */
exports.verifyDoctorSlot = async (hospitalId, doctorId, at) => {
  const doc = await UserAccount.findOne({
    _id: doctorId,
    hospitalId,
    role: 'provider',
    providerRole: 'doctor',
    isActive: true,
  });
  if (!doc) return false;
  const slots = await loadSlotsForHospital(hospitalId);
  return isDoctorFreeAt(doctorId, hospitalId, at, slots);
};

module.exports = exports;
