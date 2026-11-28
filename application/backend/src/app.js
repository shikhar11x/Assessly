'use strict';

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');

const pkg = require('../package.json');
const authRoutes = require('./auth_routes');
const studentRoutes = require('./student_routes');
const codingRoutes = require('./coding_routes');
const teacherRoutes = require('./teacher_routes');
const adminRoutes = require('./admin_routes');

/**
 * Builds and returns the Express application.
 * Kept separate from server.js so tests can use it without binding a port.
 */
function createApp() {
  const app = express();

  app.disable('x-powered-by');
  app.use(helmet());
  app.use(cors({ origin: process.env.CORS_ORIGIN ? process.env.CORS_ORIGIN.split(',').map((s) => s.trim()) : '*' }));
  app.use(express.json({ limit: '1mb' }));
  app.use('/api/auth', authRoutes);
app.use('/api/student', studentRoutes);
app.use('/api/student', codingRoutes);
app.use('/api/teacher', teacherRoutes);
app.use('/api/admin', adminRoutes);

  // Liveness endpoint: "is the process alive?" (used later by Kubernetes probes)
  app.get('/health', (req, res) => {
    res.status(200).json({
      status: 'ok',
      service: pkg.name,
      version: pkg.version,
      uptimeSeconds: Math.round(process.uptime()),
      timestamp: new Date().toISOString(),
    });
  });

  // 404 for unknown routes
  app.use((req, res) => {
    res.status(404).json({ error: 'Not Found', path: req.originalUrl });
  });

  // Central error handler
  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    console.error(err);
    res.status(err.status || 500).json({ error: err.message || 'Internal Server Error' });
  });

  return app;
}

module.exports = { createApp };
