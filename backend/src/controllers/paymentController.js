const {
  PaymentIntent,
  Patient,
  Subscription,
  Appointment,
  Hospital,
} = require('../models');
const {
  generateTxRef,
  initializePayment,
  verifyTransaction,
  isSuccessfulVerification,
} = require('../services/chapaService');
const { notifyHospital, notifyPatient } = require('../services/socketService');
const { normalizeChapaPhone } = require('../utils/chapaPhone');

async function patientContact(patientId) {
  const p = await Patient.findById(patientId).lean();
  if (!p) throw new Error('Patient not found');
  const parts = (p.name || 'Patient').trim().split(/\s+/);
  return {
    firstName: parts[0] || 'Patient',
    lastName: parts.slice(1).join(' ') || 'User',
    phone: normalizeChapaPhone(p.phone),
    email: `patient${String(p.phone).replace(/\D/g, '').slice(-9)}@gmail.com`,
  };
}

async function fulfillPaymentIntent(intent) {
  if (intent.status === 'paid') {
    return { alreadyFulfilled: true };
  }

  if (intent.purpose === 'subscription') {
    const patientId = intent.patientId;
    const pending = await Subscription.findOne({ patientId, status: 'pending' });
    if (pending) {
      pending.status = 'approved';
      pending.amount = intent.amount;
      pending.paymentMethod = 'chapa';
      pending.chapaTxRef = intent.txRef;
      pending.reviewedAt = new Date();
      const expiry = new Date();
      expiry.setFullYear(expiry.getFullYear() + 1);
      pending.expiresAt = expiry;
      await pending.save();
    } else {
      const expiry = new Date();
      expiry.setFullYear(expiry.getFullYear() + 1);
      await Subscription.create({
        patientId,
        amount: intent.amount,
        paymentMethod: 'chapa',
        chapaTxRef: intent.txRef,
        status: 'approved',
        expiresAt: expiry,
        reviewedAt: new Date(),
      });
    }

    await Patient.findByIdAndUpdate(patientId, {
      subscriptionStatus: 'active',
      isVerified: true,
    });

    notifyPatient(patientId.toString(), 'subscription_update', {
      status: 'approved',
      expiresAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
    });

    intent.status = 'paid';
    intent.paidAt = new Date();
    await intent.save();
    return { subscription: true };
  }

  if (intent.purpose === 'appointment') {
    const meta = intent.meta || {};
    const existing = await Appointment.findOne({ chapaTxRef: intent.txRef });
    if (existing) {
      intent.status = 'paid';
      intent.paidAt = new Date();
      await intent.save();
      return { appointment: existing, alreadyFulfilled: true };
    }

    const appointment = await Appointment.create({
      patientId: intent.patientId,
      hospitalId: meta.hospitalId,
      measurementId: meta.measurementId,
      aiInsightId: meta.aiInsightId || null,
      bookingFee: intent.amount,
      paymentMethod: 'chapa',
      paymentStatus: 'paid',
      chapaTxRef: intent.txRef,
      conditionLabel: meta.conditionLabel || '',
      status: 'pending',
    });

    const patient = await Patient.findById(intent.patientId, 'name phone');
    notifyHospital(meta.hospitalId, 'new_appointment_request', {
      appointmentId: appointment._id,
      patientName: patient?.name,
      patientPhone: patient?.phone,
      conditionLabel: appointment.conditionLabel,
      bookingFee: appointment.bookingFee,
      paymentStatus: 'paid',
    });

    intent.status = 'paid';
    intent.paidAt = new Date();
    await intent.save();
    return { appointment };
  }

  throw new Error('Unknown payment purpose');
}

async function markPaidFromChapa(intent, verifyResponse) {
  intent.chapaReference = verifyResponse?.data?.reference || intent.chapaReference;
  return fulfillPaymentIntent(intent);
}

exports.getPaymentConfig = async (_req, res) => {
  res.json({
    subscriptionAmountEtb: Number(process.env.SUBSCRIPTION_AMOUNT_ETB || 500),
    currency: 'ETB',
  });
};

exports.initSubscriptionPayment = async (req, res) => {
  try {
    const patientId = req.user.id;
    const amount = Number(process.env.SUBSCRIPTION_AMOUNT_ETB || 500);
    if (!amount || amount <= 0) {
      return res.status(500).json({ error: 'Subscription amount is not configured' });
    }

    const active = await Subscription.findOne({
      patientId,
      status: 'approved',
      expiresAt: { $gt: new Date() },
    });
    if (active) {
      return res.status(409).json({ error: 'You already have an active subscription' });
    }

    const txRef = generateTxRef('sub');
    await PaymentIntent.create({
      txRef,
      patientId,
      purpose: 'subscription',
      amount,
    });

    const contact = await patientContact(patientId);
    const { checkoutUrl } = await initializePayment({
      txRef,
      amount,
      ...contact,
      firstName: contact.firstName,
      lastName: contact.lastName,
      title: 'SHK Subscription',
      description: 'Annual subscription',
    });

    res.json({ checkoutUrl, txRef, amount, currency: 'ETB' });
  } catch (err) {
    console.error('initSubscriptionPayment:', err.message);
    res.status(500).json({ error: err.message });
  }
};

exports.initAppointmentPayment = async (req, res) => {
  try {
    const patientId = req.user.id;
    const { hospitalId, measurementId, aiInsightId, conditionLabel } = req.body;

    if (!hospitalId || !measurementId) {
      return res.status(400).json({ error: 'hospitalId and measurementId are required' });
    }

    const hospital = await Hospital.findOne({ _id: hospitalId, isActive: true });
    if (!hospital) return res.status(404).json({ error: 'Hospital not found' });

    const amount = Number(hospital.bookingFee);
    if (!amount || amount <= 0) {
      return res.status(400).json({ error: 'This hospital has no booking fee configured' });
    }

    const txRef = generateTxRef('appt');
    await PaymentIntent.create({
      txRef,
      patientId,
      purpose: 'appointment',
      amount,
      meta: {
        hospitalId,
        measurementId,
        aiInsightId: aiInsightId || null,
        conditionLabel: conditionLabel || '',
      },
    });

    const contact = await patientContact(patientId);
    const { checkoutUrl } = await initializePayment({
      txRef,
      amount,
      ...contact,
      firstName: contact.firstName,
      lastName: contact.lastName,
      title: hospital.name,
      description: 'Appointment fee',
    });

    res.json({ checkoutUrl, txRef, amount, currency: 'ETB', hospitalName: hospital.name });
  } catch (err) {
    console.error('initAppointmentPayment:', err.message);
    res.status(500).json({ error: err.message });
  }
};

exports.verifyPayment = async (req, res) => {
  try {
    const { txRef } = req.params;
    const intent = await PaymentIntent.findOne({ txRef, patientId: req.user.id });
    if (!intent) return res.status(404).json({ error: 'Payment not found' });

    if (intent.status === 'paid') {
      return res.json({ status: 'paid', purpose: intent.purpose });
    }

    const verifyResponse = await verifyTransaction(txRef);
    if (!isSuccessfulVerification(verifyResponse)) {
      return res.json({ status: 'pending', message: 'Payment not completed yet' });
    }

    const result = await markPaidFromChapa(intent, verifyResponse);
    res.json({
      status: 'paid',
      purpose: intent.purpose,
      appointment: result.appointment || undefined,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

async function handleChapaCallback(txRef, res) {
  if (!txRef) {
    return res.status(400).json({ error: 'Missing tx_ref' });
  }

  const intent = await PaymentIntent.findOne({ txRef });
  if (!intent) {
    return res.status(404).json({ error: 'Unknown payment' });
  }

  if (intent.status === 'paid') {
    return res.status(200).json({ ok: true });
  }

  const verifyResponse = await verifyTransaction(txRef);
  if (isSuccessfulVerification(verifyResponse)) {
    await markPaidFromChapa(intent, verifyResponse);
  }

  return res.status(200).json({ ok: true });
}

/** Chapa may POST (webhook) or GET (callback_url) after checkout */
exports.chapaWebhook = async (req, res) => {
  try {
    const txRef =
      req.body?.tx_ref
      || req.body?.trx_ref
      || req.query?.tx_ref
      || req.query?.trx_ref;
    await handleChapaCallback(txRef, res);
  } catch (err) {
    console.error('Chapa webhook error:', err.message);
    res.status(500).json({ error: err.message });
  }
};

exports.chapaReturn = (_req, res) => {
  res.type('html').send(
    '<!DOCTYPE html><html><body style="font-family:sans-serif;text-align:center;padding:2rem">'
    + '<h2>Payment complete</h2><p>You can close this page and return to the Smart Health Kiosk app.</p>'
    + '<p>Tap <strong>Confirm payment</strong> in the app if your status has not updated.</p>'
    + '</body></html>',
  );
};
