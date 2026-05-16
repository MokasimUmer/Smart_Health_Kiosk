const mongoose = require('mongoose');

const appointmentSchema = new mongoose.Schema({
  patientId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Patient',
    required: true,
  },
  hospitalId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Hospital',
    required: true,
  },
  measurementId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Measurement',
    required: true,
  },
  aiInsightId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'AIInsight',
    default: null,
  },
  bookingFee: { type: Number, required: true },
  paymentMethod: { type: String, default: 'chapa' },
  paymentStatus: {
    type: String,
    enum: ['pending', 'paid', 'failed'],
    default: 'paid',
  },
  chapaTxRef: { type: String, default: '', index: true },
  conditionLabel: { type: String, default: '' },
  status: {
    type: String,
    enum: ['pending', 'approved', 'rejected', 'cancelled'],
    default: 'pending',
  },
  reviewedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'UserAccount', default: null },
  reviewedAt: { type: Date, default: null },
  rejectionReason: { type: String, default: '' },
  appointmentDate: { type: Date, default: null },
  assignedDoctorId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'UserAccount',
    default: null,
  },
  assignedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'UserAccount',
    default: null,
  },
}, { timestamps: true });

appointmentSchema.index({ hospitalId: 1, status: 1 });
appointmentSchema.index({ patientId: 1 });

module.exports = mongoose.model('Appointment', appointmentSchema);
