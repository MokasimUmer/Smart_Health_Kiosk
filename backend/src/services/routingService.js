/**
 * Driving route between two points. OSRM (free) by default; Google Directions if configured.
 */

function haversineKm(lat1, lon1, lat2, lon2) {
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

function decodeGooglePolyline(encoded) {
  const points = [];
  let index = 0;
  let lat = 0;
  let lng = 0;
  while (index < encoded.length) {
    let b;
    let shift = 0;
    let result = 0;
    do {
      b = encoded.charCodeAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    const dlat = (result & 1) ? ~(result >> 1) : result >> 1;
    lat += dlat;
    shift = 0;
    result = 0;
    do {
      b = encoded.charCodeAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    const dlng = (result & 1) ? ~(result >> 1) : result >> 1;
    lng += dlng;
    points.push({ lat: lat / 1e5, lng: lng / 1e5 });
  }
  return points;
}

async function routeWithOsrm(fromLat, fromLng, toLat, toLng) {
  const url =
    `https://router.project-osrm.org/route/v1/driving/${fromLng},${fromLat};${toLng},${toLat}`
    + '?overview=full&geometries=geojson';
  const res = await fetch(url, {
    headers: { 'User-Agent': 'SmartHealthKiosk/1.0' },
  });
  const data = await res.json();
  if (data.code !== 'Ok' || !data.routes?.[0]) {
    throw new Error('Could not compute route');
  }
  const route = data.routes[0];
  const coordinates = route.geometry.coordinates.map(([lng, lat]) => ({ lat, lng }));
  return {
    provider: 'osrm',
    points: coordinates,
    distanceKm: Math.round((route.distance / 1000) * 100) / 100,
    durationMinutes: Math.round(route.duration / 60),
  };
}

async function routeWithGoogle(fromLat, fromLng, toLat, toLng, apiKey) {
  const url = new URL('https://maps.googleapis.com/maps/api/directions/json');
  url.searchParams.set('origin', `${fromLat},${fromLng}`);
  url.searchParams.set('destination', `${toLat},${toLng}`);
  url.searchParams.set('mode', 'driving');
  url.searchParams.set('key', apiKey);

  const res = await fetch(url.toString());
  const data = await res.json();
  if (data.status !== 'OK' || !data.routes?.[0]) {
    throw new Error(data.error_message || 'Google Directions failed');
  }
  const leg = data.routes[0].legs[0];
  const encoded = data.routes[0].overview_polyline?.points;
  const points = encoded ? decodeGooglePolyline(encoded) : [];
  return {
    provider: 'google',
    points,
    distanceKm: Math.round((leg.distance.value / 1000) * 100) / 100,
    durationMinutes: Math.round(leg.duration.value / 60),
  };
}

async function getDrivingRoute(fromLat, fromLng, toLat, toLng) {
  const useGoogle =
    process.env.MAP_ROUTING_PROVIDER === 'google'
    && process.env.GOOGLE_MAPS_API_KEY
    && process.env.GOOGLE_MAPS_API_KEY !== 'your_google_maps_api_key';

  if (useGoogle) {
    try {
      return await routeWithGoogle(fromLat, fromLng, toLat, toLng, process.env.GOOGLE_MAPS_API_KEY);
    } catch (err) {
      console.warn('Google routing failed, falling back to OSRM:', err.message);
    }
  }

  try {
    return await routeWithOsrm(fromLat, fromLng, toLat, toLng);
  } catch (err) {
    const straightKm = haversineKm(fromLat, fromLng, toLat, toLng);
    return {
      provider: 'straight',
      points: [{ lat: fromLat, lng: fromLng }, { lat: toLat, lng: toLng }],
      distanceKm: straightKm,
      durationMinutes: null,
    };
  }
}

module.exports = { getDrivingRoute, haversineKm };
