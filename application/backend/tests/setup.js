'use strict';
// Runs before every test file. Provides test-only config; real secrets stay in .env.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test-secret-for-jest-only-not-real-32chars';
process.env.JWT_EXPIRES_IN = '1h';
process.env.DATABASE_URL = process.env.DATABASE_URL || 'postgres://assessly:x@localhost:5433/assessly';
