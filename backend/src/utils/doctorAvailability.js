const UserAccount = require('../models/UserAccount');
const DoctorAvailability = require('../models/DoctorAvailability');

function timeToMinutes(t) {
  const [h, m] = String(t).split(':').map(Number);
  return h * 60 + m;
}

/** @param {Date} at */
function isDoctorFreeAt(doctorId, hospitalId, at, slots) {
  const dow = at.getDay();
  const mins = at.getHours() * 60 + at.getMinutes();
  const daySlots = slots.filter(
    (s) => s.doctorId.toString() === doctorId.toString()
      && s.hospitalId.toString() === hospitalId.toString()
      && s.dayOfWeek === dow,
  );
  for (const s of daySlots) {
    const a = timeToMinutes(s.startTime);
    const b = timeToMinutes(s.endTime);
    if (a <= b) {
      if (mins >= a && mins < b) return true;
    } else {
      if (mins >= a || mins < b) return true;
    }
  }
  return false;
}

async function loadSlotsForHospital(hospitalId) {
  return DoctorAvailability.find({ hospitalId }).lean();
}

/**
 * @param {import('mongoose').Types.ObjectId} hospitalId
 * @param {Date} at
 * @param {string|null} excludeDoctorId
 */
async function listDoctorsFreeAt(hospitalId, at, excludeDoctorId = null) {
  const doctors = await UserAccount.find({
    hospitalId,
    role: 'provider',
    providerRole: 'doctor',
    isActive: true,
  }).select('name username').lean();

  const slots = await loadSlotsForHospital(hospitalId);
  const out = [];
  for (const d of doctors) {
    if (excludeDoctorId && d._id.toString() === excludeDoctorId) continue;
    if (isDoctorFreeAt(d._id, hospitalId, at, slots)) out.push(d);
  }
  return out;
}

async function assertDoctorAvailableForAppointment(hospitalId, doctorId, at) {
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
}

module.exports = {
  timeToMinutes,
  isDoctorFreeAt,
  loadSlotsForHospital,
  listDoctorsFreeAt,
  assertDoctorAvailableForAppointment,
};
