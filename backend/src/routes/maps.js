const router = require('express').Router();
const { getDrivingRoute } = require('../services/routingService');
const { authenticate } = require('../middleware/auth');

router.get('/route', authenticate, async (req, res) => {
  try {
    const fromLat = Number(req.query.fromLat);
    const fromLng = Number(req.query.fromLng);
    const toLat = Number(req.query.toLat);
    const toLng = Number(req.query.toLng);

    if ([fromLat, fromLng, toLat, toLng].some((n) => Number.isNaN(n))) {
      return res.status(400).json({ error: 'fromLat, fromLng, toLat, toLng are required numbers' });
    }

    const route = await getDrivingRoute(fromLat, fromLng, toLat, toLng);
    res.json(route);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
