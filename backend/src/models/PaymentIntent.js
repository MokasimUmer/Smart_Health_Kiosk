const mongoose = require('mongoose');

/** Pending Chapa checkout; fulfilled on successful payment. */
const paymentIntentSchema = new mongoose.Schema({
  txRef: { type: String, required: true, unique: true, index: true },
  patientId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Patient',
    required: true,
    index: true,
  },
  purpose: {
    type: String,
    enum: ['subscription', 'appointment'],
    required: true,
  },
  amount: { type: Number, required: true },
  currency: { type: String, default: 'ETB' },
  status: {
    type: String,
    enum: ['pending', 'paid', 'failed'],
    default: 'pending',
  },
  /** Appointment booking fields or subscription metadata */
  meta: { type: mongoose.Schema.Types.Mixed, default: {} },
  chapaReference: { type: String, default: '' },
  paidAt: { type: Date, default: null },
}, { timestamps: true });

module.exports = mongoose.model('PaymentIntent', paymentIntentSchema);
