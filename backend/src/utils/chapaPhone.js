/** Chapa expects 10 digits: 09xxxxxxxx or 07xxxxxxxx */
function normalizeChapaPhone(raw) {
  let digits = String(raw || '').replace(/\D/g, '');
  if (digits.startsWith('251')) digits = digits.slice(3);
  if (digits.startsWith('0')) digits = digits.slice(1);
  if (digits.length >= 9) {
    const nine = digits.slice(-9);
    return `0${nine}`;
  }
  return '0912345678';
}

module.exports = { normalizeChapaPhone };
