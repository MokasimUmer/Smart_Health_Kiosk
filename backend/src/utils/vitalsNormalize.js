function normalizeVitals(vitals) {
  if (!vitals || typeof vitals !== 'object') return vitals;
  const out = { ...vitals };
  if (out.weightKg === 0) out.weightKg = null;
  const w = out.weightKg;
  if (w != null && (w < 1 || w >= 400)) out.weightKg = null;
  const hr = out.heartRate;
  if (hr == null || hr === 0 || hr < 35 || hr > 240) out.heartRate = null;
  const sp = out.spo2;
  if (sp == null || sp === 0 || sp < 50 || sp > 100) out.spo2 = null;
  const t = out.temperatureCelsius;
  if (t != null && (t < 15 || t > 50)) out.temperatureCelsius = null;
  const h = out.heightCm;
  if (h != null && (h < 40 || h > 280)) out.heightCm = null;
  if (out.bmi != null && (out.heightCm == null || out.weightKg == null)) {
    out.bmi = null;
  }
  return out;
}

module.exports = { normalizeVitals };
