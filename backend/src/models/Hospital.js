const mongoose = require('mongoose');

const hospitalSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true },
  location: {
    type: { type: String, enum: ['Point'], default: 'Point' },
    coordinates: { type: [Number], required: true },
  },
  address: { type: String, default: '' },
  phone: { type: String, default: '' },
  specializations: [{ type: String }],
  bookingFee: { type: Number, default: 0 },
  isActive: { type: Boolean, default: true },
  googlePlaceId: { type: String, default: null },
  imageUrl: { type: String, default: null },
}, { timestamps: true });

hospitalSchema.index({ location: '2dsphere' });

module.exports = mongoose.model('Hospital', hospitalSchema);
