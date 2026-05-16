const mongoose = require('mongoose');

/** Weekly recurring availability (local wall-clock for the hospital). */
const doctorAvailabilitySchema = new mongoose.Schema({
  hospitalId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Hospital',
    required: true,
    index: true,
  },
  doctorId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'UserAccount',
    required: true,
    index: true,
  },
  /** 0 = Sunday … 6 = Saturday (JavaScript Date.getDay()) */
  dayOfWeek: { type: Number, required: true, min: 0, max: 6 },
  /** "HH:mm" 24h */
  startTime: { type: String, required: true, match: /^([01]\d|2[0-3]):[0-5]\d$/ },
  endTime: { type: String, required: true, match: /^([01]\d|2[0-3]):[0-5]\d$/ },
}, { timestamps: true });

doctorAvailabilitySchema.index({ hospitalId: 1, doctorId: 1, dayOfWeek: 1 });

module.exports = mongoose.model('DoctorAvailability', doctorAvailabilitySchema);
