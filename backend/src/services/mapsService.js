const { Hospital } = require('../models');

/** Score for sorting: LLM rankKeywords vs name, address, specializations (substring, case-insensitive). */
function hospitalKeywordScore(h, rankKeywords) {
  if (!rankKeywords || !rankKeywords.length) return 0;
  const specs = Array.isArray(h.specializations) ? h.specializations : [];
  const hay = [h.name, h.address, ...specs].filter(Boolean).join(' ').toLowerCase();
  let score = 0;
  for (const raw of rankKeywords.slice(0, 2)) {
    const k = String(raw).toLowerCase().trim();
    if (k.length < 2) continue;
    if (hay.includes(k)) score += 10;
  }
  return score;
}

function sortHospitalsByRank(lat, lng, rows, rankKeywords) {
  const withDist = rows.map(h => ({
    h,
    dist: calculateDistance(lat, lng, h.location.coordinates[1], h.location.coordinates[0]),
    score: hospitalKeywordScore(h, rankKeywords),
  }));
  withDist.sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    if (a.dist !== b.dist) return a.dist - b.dist;
    const fa = a.h.bookingFee != null ? a.h.bookingFee : Number.POSITIVE_INFINITY;
    const fb = b.h.bookingFee != null ? b.h.bookingFee : Number.POSITIVE_INFINITY;
    return fa - fb;
  });
  return withDist;
}

async function findNearbyHospitals(lat, lng, conditionCategory, radiusMeters = 50000, rankKeywords = []) {
  const googleQuery = (rankKeywords && rankKeywords[0]) || conditionCategory;
  const registeredHospitals = await findRegisteredHospitals(lat, lng, radiusMeters, rankKeywords);
  let googleHospitals = [];

  const apiKey = process.env.GOOGLE_MAPS_API_KEY;
  if (apiKey && apiKey !== 'your_google_maps_api_key') {
    googleHospitals = await searchGoogleMaps(lat, lng, googleQuery, radiusMeters, apiKey);
  }

  const registeredPlaceIds = new Set(
    registeredHospitals.filter(h => h.googlePlaceId).map(h => h.googlePlaceId)
  );
  let externalHospitals = googleHospitals
    .filter(g => !registeredPlaceIds.has(g.placeId))
    .map(g => ({
      source: 'google_maps',
      name: g.name,
      address: g.address,
      distance: g.distance,
      placeId: g.placeId,
      location: g.location,
      bookingFee: null,
      specializations: [],
    }));

  const extRows = externalHospitals.map(e => ({
    name: e.name,
    address: e.address,
    specializations: e.specializations || [],
    location: e.location,
    bookingFee: e.bookingFee,
    _raw: e,
  }));
  const sortedExt = sortHospitalsByRank(lat, lng, extRows, rankKeywords);
  externalHospitals = sortedExt.map(({ h }) => h._raw);

  return {
    registered: registeredHospitals,
    external: externalHospitals,
  };
}

async function findRegisteredHospitals(lat, lng, radiusMeters, rankKeywords = []) {
  const query = {
    isActive: true,
    location: {
      $near: {
        $geometry: { type: 'Point', coordinates: [lng, lat] },
        $maxDistance: radiusMeters,
      },
    },
  };

  const hospitals = await Hospital.find(query).limit(20).lean();
  const sorted = sortHospitalsByRank(lat, lng, hospitals, rankKeywords);

  return sorted.map(({ h, dist }) => ({
    source: 'registered',
    _id: h._id,
    name: h.name,
    address: h.address,
    specializations: h.specializations,
    bookingFee: h.bookingFee,
    location: h.location,
    imageUrl: h.imageUrl || null,
    googlePlaceId: h.googlePlaceId || null,
    distance: dist,
  }));
}

async function searchGoogleMaps(lat, lng, keyword, radiusMeters, apiKey) {
  const url = new URL('https://maps.googleapis.com/maps/api/place/nearbysearch/json');
  url.searchParams.set('location', `${lat},${lng}`);
  url.searchParams.set('radius', String(radiusMeters));
  url.searchParams.set('type', 'hospital');
  if (keyword && keyword !== 'normal') {
    url.searchParams.set('keyword', keyword);
  }
  url.searchParams.set('key', apiKey);

  try {
    const res = await fetch(url.toString());
    const data = await res.json();
    if (data.status !== 'OK') return [];

    return data.results.map(place => ({
      name: place.name,
      address: place.vicinity || '',
      placeId: place.place_id,
      location: {
        type: 'Point',
        coordinates: [place.geometry.location.lng, place.geometry.location.lat],
      },
      distance: calculateDistance(lat, lng, place.geometry.location.lat, place.geometry.location.lng),
    }));
  } catch (err) {
    console.error('Google Maps API error:', err.message);
    return [];
  }
}

function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
    Math.cos((lat2 * Math.PI) / 180) *
    Math.sin(dLon / 2) ** 2;
  return Math.round(R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)) * 100) / 100;
}

module.exports = { findNearbyHospitals };
