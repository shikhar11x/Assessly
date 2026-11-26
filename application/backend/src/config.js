'use strict';

require('dotenv').config({ quiet: true });

/** Central configuration. Fails fast if a required secret is missing. */
const config = {
  port: parseInt(process.env.PORT, 10) || 3000,
  databaseUrl: process.env.DATABASE_URL,
  jwtSecret: process.env.JWT_SECRET,
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '2h',
};

if (process.env.NODE_ENV !== 'test') {
  for (const key of ['databaseUrl', 'jwtSecret']) {
    if (!config[key]) throw new Error(`Missing required config: ${key}`);
  }
}

module.exports = config;
