'use strict';

require('dotenv').config();
const { createApp } = require('./app');

const PORT = parseInt(process.env.PORT, 10) || 3000;
const app = createApp();

const server = app.listen(PORT, () => {
  console.log(`Assessly backend listening on port ${PORT}`);
});

// Graceful shutdown: Docker and Kubernetes send SIGTERM before killing a container.
function shutdown(signal) {
  console.log(`${signal} received, shutting down gracefully...`);
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(1), 10000).unref();
}
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
