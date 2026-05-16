const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userAccountSchema = new mongoose.Schema({
  username: { type: String, required: true, unique: true, trim: true },
  password: { type: String, required: true, minlength: 6 },
  role: {
    type: String,
    enum: ['provider', 'super_admin'],
    required: true,
  },
  /** For role=provider: hospital coordinator vs staff doctor */
  providerRole: {
    type: String,
    enum: ['hospital_admin', 'doctor'],
    default: 'hospital_admin',
  },
  name: { type: String, required: true, trim: true },
  hospitalId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Hospital',
    default: null,
  },
  isActive: { type: Boolean, default: true },
}, { timestamps: true });

userAccountSchema.pre('save', async function () {
  if (!this.isModified('password')) return;
  this.password = await bcrypt.hash(this.password, 12);
});

userAccountSchema.methods.comparePassword = async function (candidate) {
  return bcrypt.compare(candidate, this.password);
};

userAccountSchema.methods.toJSON = function () {
  const obj = this.toObject();
  delete obj.password;
  return obj;
};

module.exports = mongoose.model('UserAccount', userAccountSchema);
