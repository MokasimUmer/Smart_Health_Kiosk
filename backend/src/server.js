require('dotenv').config();
const express = require('express');
const http = require('http');
const cors = require('cors');
const path = require('path');
const connectDB = require('./config/db');
const socketService = require('./services/socketService');
const mqttService = require('./services/mqttService');

const authRoutes = require('./routes/auth');
const subscriptionRoutes = require('./routes/subscriptions');
const measurementRoutes = require('./routes/measurements');
const appointmentRoutes = require('./routes/appointments');
const adminRoutes = require('./routes/admin');
const staffRoutes = require('./routes/staff');
const paymentRoutes = require('./routes/payments');
const mapsRoutes = require('./routes/maps');

const app = express();
const server = http.createServer(app);

app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

app.use('/api/auth', authRoutes);
app.use('/api/subscriptions', subscriptionRoutes);
app.use('/api/measurements', measurementRoutes);
app.use('/api/appointments', appointmentRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/staff', staffRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/maps', mapsRoutes);

app.get('/', (_req, res) => {
  res.json({
    service: 'Smart Health Kiosk API',
    status: 'ok',
    health: '/api/health',
    docs: 'All routes are under /api/*',
  });
});

app.get('/api/health', (_req, res) => res.json({ status: 'ok' }));

const PORT = process.env.PORT || 5000;

async function start() {
  await connectDB();

  const io = socketService.init(server);
  mqttService.init(io);

  server.listen(PORT, '0.0.0.0', () => {
    console.log(`Backend server running on port ${PORT}`);
  });
}

start().catch(console.error);
