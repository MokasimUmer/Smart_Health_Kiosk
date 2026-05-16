const { Patient, UserAccount } = require('../models');
const { signToken } = require('../middleware/auth');

exports.patientSignup = async (req, res) => {
  try {
    const { name, phone, password, latitude, longitude, address, gender, dateOfBirth } = req.body;

    const existing = await Patient.findOne({ phone });
    if (existing) return res.status(409).json({ error: 'Phone number already registered' });

    const patient = await Patient.create({
      name,
      phone,
      password,
      location: { type: 'Point', coordinates: [longitude || 0, latitude || 0] },
      address: address || '',
      gender: gender || 'other',
      dateOfBirth: dateOfBirth || null,
    });

    const token = signToken({ id: patient._id, role: 'patient' });
    res.status(201).json({ token, patient });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.patientLogin = async (req, res) => {
  try {
    const { phone, password } = req.body;
    const patient = await Patient.findOne({ phone });
    if (!patient || !(await patient.comparePassword(password))) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const token = signToken({ id: patient._id, role: 'patient' });
    res.json({ token, patient });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.staffLogin = async (req, res) => {
  try {
    const { username, password } = req.body;
    const user = await UserAccount.findOne({ username, isActive: true });
    if (!user || !(await user.comparePassword(password))) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const token = signToken({
      id: user._id,
      role: user.role,
      hospitalId: user.hospitalId?.toString() || null,
      providerRole: user.role === 'provider' ? (user.providerRole || 'hospital_admin') : undefined,
    });
    res.json({ token, user });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.getMe = async (req, res) => {
  try {
    if (req.user.role === 'patient') {
      const patient = await Patient.findById(req.user.id);
      return res.json({ user: patient, role: 'patient' });
    }
    const user = await UserAccount.findById(req.user.id).populate('hospitalId');
    res.json({ user, role: user.role });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
