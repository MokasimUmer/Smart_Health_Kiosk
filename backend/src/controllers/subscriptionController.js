const { Subscription, Patient } = require('../models');
const { notifyPatient } = require('../services/socketService');

exports.getMySubscription = async (req, res) => {
  try {
    const sub = await Subscription.findOne({ patientId: req.user.id })
      .sort({ createdAt: -1 });
    res.json({ subscription: sub });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.getPendingSubscriptions = async (_req, res) => {
  try {
    const subs = await Subscription.find({ status: 'pending' })
      .populate('patientId', 'name phone address')
      .sort({ createdAt: 1 });
    res.json({ subscriptions: subs });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.getAllSubscriptions = async (req, res) => {
  try {
    const { status } = req.query;
    const filter = status ? { status } : {};
    const subs = await Subscription.find(filter)
      .populate('patientId', 'name phone address')
      .sort({ createdAt: -1 });
    res.json({ subscriptions: subs });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.reviewSubscription = async (req, res) => {
  try {
    const { id } = req.params;
    const { action, rejectionReason } = req.body;

    if (!['approve', 'reject'].includes(action)) {
      return res.status(400).json({ error: 'Action must be approve or reject' });
    }

    const sub = await Subscription.findById(id);
    if (!sub) return res.status(404).json({ error: 'Subscription not found' });
    if (sub.status !== 'pending') {
      return res.status(400).json({ error: 'Subscription already reviewed' });
    }

    sub.status = action === 'approve' ? 'approved' : 'rejected';
    sub.reviewedBy = req.user.id;
    sub.reviewedAt = new Date();
    if (action === 'approve') {
      const expiry = new Date();
      expiry.setFullYear(expiry.getFullYear() + 1);
      sub.expiresAt = expiry;
    }
    if (action === 'reject') {
      sub.rejectionReason = rejectionReason || '';
    }
    await sub.save();

    if (action === 'approve') {
      await Patient.findByIdAndUpdate(sub.patientId, {
        subscriptionStatus: 'active',
        isVerified: true,
      });
    } else {
      await Patient.findByIdAndUpdate(sub.patientId, {
        subscriptionStatus: 'rejected',
      });
    }

    notifyPatient(sub.patientId.toString(), 'subscription_update', {
      status: sub.status,
      expiresAt: sub.expiresAt,
    });

    res.json({ subscription: sub });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
