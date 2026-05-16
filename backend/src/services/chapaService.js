const crypto = require('crypto');
const { normalizeChapaPhone } = require('../utils/chapaPhone');

const CHAPA_BASE = 'https://api.chapa.co/v1';

function secretKey() {
  const key = process.env.CHAPA_SECRET_KEY;
  if (!key || key === 'your_chapa_secret_key') {
    throw new Error('CHAPA_SECRET_KEY is not configured');
  }
  return key;
}

function publicBaseUrl() {
  return (process.env.PUBLIC_BASE_URL || `http://localhost:${process.env.PORT || 5000}`).replace(/\/$/, '');
}

function generateTxRef(prefix = 'shk') {
  return `${prefix}_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`;
}

/** Chapa limit: customization.title max 16 characters */
function truncateChapaTitle(text, maxLen = 16) {
  const t = String(text || 'Smart Health').trim();
  return t.length <= maxLen ? t : t.slice(0, maxLen);
}

async function chapaFetch(path, options = {}) {
  const res = await fetch(`${CHAPA_BASE}${path}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${secretKey()}`,
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok || String(data.status).toLowerCase() === 'failed') {
    let msg = data.message || data.status || res.statusText || 'Chapa request failed';
    if (typeof msg === 'object') msg = JSON.stringify(msg);
    throw new Error(String(msg));
  }
  return data;
}

/**
 * @param {object} params
 * @param {string} params.txRef
 * @param {string|number} params.amount ETB
 * @param {string} params.email
 * @param {string} params.firstName
 * @param {string} params.lastName
 * @param {string} params.phone
 * @param {string} params.title
 */
async function initializePayment(params) {
  const body = {
    amount: String(params.amount),
    currency: 'ETB',
    email: params.email || 'patient@gmail.com',
    first_name: params.firstName || 'Patient',
    last_name: params.lastName || 'User',
    phone_number: normalizeChapaPhone(params.phone),
    tx_ref: params.txRef,
    callback_url: `${publicBaseUrl()}/api/payments/chapa/webhook`,
    return_url: params.returnUrl || `${publicBaseUrl()}/api/payments/chapa/return`,
    customization: {
      title: truncateChapaTitle(params.title || 'Smart Health'),
      description: (params.description || 'Payment').slice(0, 200),
    },
  };

  const data = await chapaFetch('/transaction/initialize', {
    method: 'POST',
    body: JSON.stringify(body),
  });

  const checkoutUrl = data?.data?.checkout_url;
  if (!checkoutUrl) {
    throw new Error('Chapa did not return a checkout URL');
  }
  return { checkoutUrl, raw: data };
}

async function verifyTransaction(txRef) {
  const data = await chapaFetch(`/transaction/verify/${encodeURIComponent(txRef)}`, {
    method: 'GET',
  });
  return data;
}

function isSuccessfulVerification(verifyResponse) {
  const status = verifyResponse?.data?.status || verifyResponse?.status;
  const s = String(status).toLowerCase();
  return s === 'success' || s === 'successful';
}

module.exports = {
  generateTxRef,
  publicBaseUrl,
  initializePayment,
  verifyTransaction,
  isSuccessfulVerification,
};
