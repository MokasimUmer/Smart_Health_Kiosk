const {
  Appointment,
  PatientHospitalAccess,
  Measurement,
  Patient,
  AIInsight,
} = require('../models');
const { notifyHospital, notifyPatient } = require('../services/socketService');
const { assertDoctorAvailableForAppointment } = require('../utils/doctorAvailability');

function staffRole(req) {
  return req.user.providerRole || 'hospital_admin';
}

exports.getMyAppointments = async (req, res) => {
  try {
    const appointments = await Appointment.find({ patientId: req.user.id })
      .populate('hospitalId', 'name address specializations imageUrl')
      .populate('assignedDoctorId', 'name username')
      .sort({ createdAt: -1 });
    res.json({ appointments });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.getHospitalAppointments = async (req, res) => {
  try {
    const hospitalId = req.user.hospitalId;
    if (!hospitalId) return res.status(403).json({ error: 'No hospital assigned' });

    const { status } = req.query;
    const filter = { hospitalId };
    if (status) filter.status = status;

    if (req.user.role === 'provider' && staffRole(req) === 'doctor') {
      if (status === 'pending') {
        return res.json({ appointments: [] });
      }
      filter.assignedDoctorId = req.user.id;
    }

    const appointments = await Appointment.find(filter)
      .populate('patientId', 'name phone address')
      .populate('assignedDoctorId', 'name username')
      .sort({ createdAt: -1 });

    res.json({ appointments });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.reviewAppointment = async (req, res) => {
  try {
    if (req.user.role !== 'provider' || staffRole(req) !== 'hospital_admin') {
      return res.status(403).json({ error: 'Only the hospital administrator can review appointment requests' });
    }

    const { id } = req.params;
    const {
      action,
      rejectionReason,
      appointmentDate,
      assignedDoctorId,
      assignToSelf,
    } = req.body;
    const hospitalId = req.user.hospitalId;

    if (!['approve', 'reject'].includes(action)) {
      return res.status(400).json({ error: 'Action must be approve or reject' });
    }

    const appointment = await Appointment.findById(id);
    if (!appointment) return res.status(404).json({ error: 'Appointment not found' });
    if (appointment.hospitalId.toString() !== hospitalId) {
      return res.status(403).json({ error: 'Not authorized for this appointment' });
    }
    if (appointment.status !== 'pending') {
      return res.status(400).json({ error: 'Appointment already reviewed' });
    }

    const paid = !appointment.paymentStatus || appointment.paymentStatus === 'paid';
    if (action === 'approve' && !paid) {
      return res.status(400).json({ error: 'Appointment fee has not been paid yet' });
    }

    if (action === 'approve') {
      if (!appointmentDate || Number.isNaN(new Date(appointmentDate).getTime())) {
        return res.status(400).json({ error: 'A valid appointment date and time are required to approve' });
      }
      const at = new Date(appointmentDate);
      const self = assignToSelf === true || assignToSelf === 'true';
      let assignee = null;
      if (self) {
        assignee = req.user.id;
      } else if (assignedDoctorId) {
        const ok = await assertDoctorAvailableForAppointment(hospitalId, assignedDoctorId, at);
        if (!ok) {
          return res.status(400).json({
            error: 'Selected doctor is not available at that date and time. Pick another doctor or another slot.',
          });
        }
        assignee = assignedDoctorId;
      } else {
        return res.status(400).json({
          error: 'Choose a doctor who is free at this time, or select "I will see this patient myself".',
        });
      }
      appointment.assignedDoctorId = assignee;
      appointment.assignedBy = req.user.id;
    }

    if (action === 'reject') {
      if (!rejectionReason || !String(rejectionReason).trim()) {
        return res.status(400).json({ error: 'A rejection reason is required' });
      }
    }

    appointment.status = action === 'approve' ? 'approved' : 'rejected';
    appointment.reviewedBy = req.user.id;
    appointment.reviewedAt = new Date();
    if (action === 'approve') {
      appointment.appointmentDate = new Date(appointmentDate);
    }
    if (action === 'reject') {
      appointment.rejectionReason = rejectionReason || '';
      appointment.assignedDoctorId = null;
      appointment.assignedBy = null;
    }
    await appointment.save();

    if (action === 'approve') {
      await PatientHospitalAccess.create({
        patientId: appointment.patientId,
        hospitalId: appointment.hospitalId,
        appointmentId: appointment._id,
      });

      const measurement = await Measurement.findById(appointment.measurementId);
      const patient = await Patient.findById(appointment.patientId);

      notifyHospital(hospitalId, 'patient_data_granted', {
        appointmentId: appointment._id,
        patient,
        measurement,
        assignedDoctorId: appointment.assignedDoctorId,
      });
    }

    notifyPatient(appointment.patientId.toString(), 'appointment_update', {
      appointmentId: appointment._id,
      status: appointment.status,
      appointmentDate: appointment.appointmentDate,
      assignedDoctorId: appointment.assignedDoctorId,
    });

    const populated = await Appointment.findById(appointment._id)
      .populate('assignedDoctorId', 'name username');
    res.json({ appointment: populated });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

/** Reassign treating doctor after approval (admin only). */
exports.reassignAppointment = async (req, res) => {
  try {
    if (req.user.role !== 'provider' || staffRole(req) !== 'hospital_admin') {
      return res.status(403).json({ error: 'Only the hospital administrator can reassign doctors' });
    }
    const { id } = req.params;
    const { assignedDoctorId, assignToSelf } = req.body;
    const hospitalId = req.user.hospitalId;

    const appointment = await Appointment.findById(id);
    if (!appointment) return res.status(404).json({ error: 'Appointment not found' });
    if (appointment.hospitalId.toString() !== hospitalId) {
      return res.status(403).json({ error: 'Not authorized for this appointment' });
    }
    if (appointment.status !== 'approved' || !appointment.appointmentDate) {
      return res.status(400).json({ error: 'Only approved appointments with a scheduled time can be reassigned' });
    }

    const at = new Date(appointment.appointmentDate);
    const self = assignToSelf === true || assignToSelf === 'true';
    let assignee = null;
    if (self) {
      assignee = req.user.id;
    } else if (assignedDoctorId) {
      const ok = await assertDoctorAvailableForAppointment(hospitalId, assignedDoctorId, at);
      if (!ok) {
        return res.status(400).json({
          error: 'Selected doctor is not available at the scheduled date and time.',
        });
      }
      assignee = assignedDoctorId;
    } else {
      return res.status(400).json({ error: 'Provide assignedDoctorId or assignToSelf: true' });
    }

    appointment.assignedDoctorId = assignee;
    appointment.assignedBy = req.user.id;
    await appointment.save();

    const populated = await Appointment.findById(appointment._id)
      .populate('assignedDoctorId', 'name username');
    res.json({ appointment: populated });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.getHospitalPatients = async (req, res) => {
  try {
    const hospitalId = req.user.hospitalId;
    if (!hospitalId) return res.status(403).json({ error: 'No hospital assigned' });

    const accessRecords = await PatientHospitalAccess.find({
      hospitalId,
      status: 'active',
    })
      .populate('patientId')
      .populate({
        path: 'appointmentId',
        select: 'status appointmentDate conditionLabel bookingFee createdAt assignedDoctorId assignedBy reviewedBy',
        populate: [
          { path: 'assignedDoctorId', select: 'name username providerRole' },
          { path: 'assignedBy', select: 'name username' },
        ],
      });

    let records = accessRecords;
    if (req.user.role === 'provider' && staffRole(req) === 'doctor') {
      records = accessRecords.filter(
        (r) => r.appointmentId?.assignedDoctorId?._id?.toString() === req.user.id
          || r.appointmentId?.assignedDoctorId?.toString() === req.user.id,
      );
    }

    const patientIds = records.map((a) => a.patientId._id);

    const measurements = await Measurement.find({ patientId: { $in: patientIds } })
      .sort({ measuredAt: -1 })
      .lean();

    const insights = await AIInsight.find({ patientId: { $in: patientIds } })
      .sort({ createdAt: -1 })
      .lean();

    const patients = records.map((record) => {
      const pid = record.patientId._id.toString();
      return {
        patient: record.patientId,
        appointment: record.appointmentId,
        measurements: measurements.filter((m) => m.patientId.toString() === pid),
        insights: insights.filter((i) => i.patientId.toString() === pid),
      };
    });

    res.json({ patients });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
