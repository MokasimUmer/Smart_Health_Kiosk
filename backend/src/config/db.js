const dns = require('dns');
const mongoose = require('mongoose');

const MAX_ATTEMPTS = 5;
const RETRY_DELAY_MS = 15000;
const DEFAULT_DB = 'smart_health_kiosk';

// Prefer IPv4 first (helps some Windows / dual-stack setups with Atlas)
if (typeof dns.setDefaultResultOrder === 'function') {
  dns.setDefaultResultOrder('ipv4first');
}

/**
 * Do NOT force Google DNS by default: many school/corporate networks block 8.8.8.8,
 * which breaks SRV lookups for mongodb+srv:// and causes querySrv ETIMEOUT.
 * Set MONGODB_DNS_SERVERS=8.8.8.8,8.8.4.4 in .env only if you know you need it.
 */
const dnsServers = process.env.MONGODB_DNS_SERVERS;
if (dnsServers && dnsServers.trim() !== '' && dnsServers.trim().toLowerCase() !== 'default') {
  const list = dnsServers.split(',').map((s) => s.trim()).filter(Boolean);
  if (list.length) {
    dns.setServers(list);
    console.log('[db] Using MONGODB_DNS_SERVERS:', list.join(', '));
  }
}

/** Atlas URIs often look like host/?options with no DB name — add one + retryWrites. */
function normalizeMongoUri(raw) {
  let uri = String(raw || '').trim();
  if (!uri) return uri;
  if (/mongodb\+srv:\/\//i.test(uri)) {
    uri = uri.replace(/(\.mongodb\.net)\/\?/i, `$1/${DEFAULT_DB}?`);
    uri = uri.replace(/(\.mongodb\.net)\/?$/i, `$1/${DEFAULT_DB}`);
  }
  if (!/[?&]retryWrites=/.test(uri)) {
    uri += uri.includes('?') ? '&retryWrites=true&w=majority' : '?retryWrites=true&w=majority';
  }
  return uri;
}

function maskUri(uri) {
  try {
    return String(uri).replace(/:([^:@/]+)@/, ':****@');
  } catch (_) {
    return '(unable to display)';
  }
}

function hintForMongoError(err) {
  const msg = String(err?.message || err || '');
  const lower = msg.toLowerCase();
  if (lower.includes('querysrv') || (lower.includes('srv') && lower.includes('etimeout'))) {
    return [
      'DNS SRV lookup for Atlas timed out. Fixes that usually work:',
      '  1) Remove MONGODB_DNS_SERVERS from .env (use your PC’s normal DNS) — forced 8.8.8.8 often causes this on locked-down networks.',
      '  2) Try another network (phone hotspot) or disable VPN.',
      '  3) In Atlas → Connect → Drivers: copy the “standard connection string” (mongodb://host1:27017,...) and set MONGODB_URI to that instead of mongodb+srv.',
    ].join('\n');
  }
  if (lower.includes('whitelist') || (lower.includes('ip') && lower.includes('not allowed'))) {
    return 'Atlas → Network Access → add your current IP, or 0.0.0.0/0 for development only.';
  }
  if (lower.includes('authentication failed') || lower.includes('bad auth')) {
    return 'Atlas → Database Users: check user/password. Special characters in the password must be URL-encoded in MONGODB_URI.';
  }
  if (lower.includes('enotfound')) {
    return 'Check the cluster hostname in Atlas → Connect. Wrong host name or DNS blocked.';
  }
  if (lower.includes('econnrefused')) {
    return 'For local Mongo: start mongod. For Atlas: this usually means wrong host/port, not SRV.';
  }
  if (lower.includes('timed out') || lower.includes('timeout')) {
    return 'Firewall/VPN may block MongoDB. Allow outbound access or try Atlas Network Access + another network.';
  }
  return 'https://www.mongodb.com/docs/atlas/troubleshoot-connection/';
}

async function connectDB() {
  const rawUri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/smart_health_kiosk';
  const uri = normalizeMongoUri(rawUri);
  if (uri !== rawUri) {
    console.log('[db] Normalized MONGODB_URI (database path and/or retryWrites).');
  }
  console.log('[db] Connecting to', maskUri(uri));

  const opts = {
    serverSelectionTimeoutMS: 20000,
    connectTimeoutMS: 20000,
    socketTimeoutMS: 45000,
    family: 4,
  };

  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
    try {
      console.log(`[db] Attempt ${attempt}/${MAX_ATTEMPTS}…`);
      await mongoose.connect(uri, opts);
      console.log('MongoDB connected');
      return;
    } catch (err) {
      const isWhitelist = err.message && err.message.includes('whitelist');
      console.error(isWhitelist
        ? `MongoDB Atlas: IP not whitelisted (attempt ${attempt}/${MAX_ATTEMPTS}). Add 0.0.0.0/0 at https://cloud.mongodb.com → Network Access.`
        : `MongoDB connection failed (attempt ${attempt}/${MAX_ATTEMPTS}):`, err.message);
      console.error(hintForMongoError(err));
      if (attempt === MAX_ATTEMPTS) throw err;
      console.log(`Retrying in ${RETRY_DELAY_MS / 1000}s...`);
      await new Promise((r) => setTimeout(r, RETRY_DELAY_MS));
    }
  }
}

module.exports = connectDB;
