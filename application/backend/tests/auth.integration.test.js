'use strict';

// Integration tests: need the Postgres container running and migrated.
// Run with: npm run test:integration (uses the real DATABASE_URL from .env)
require('dotenv').config({ override: true, quiet: true });
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = process.env.JWT_SECRET || 'integration-secret-32-characters-long';

const request = require('supertest');
const { createApp } = require('../src/app');
const { pool } = require('../src/db');

const app = createApp();
const email = `it_${Date.now()}@assessly.local`;

afterAll(async () => {
  await pool.query('DELETE FROM users WHERE email = $1', [email]);
  await pool.end();
});

describe('auth API (integration)', () => {
  it('registers a student and returns a token', async () => {
    const res = await request(app).post('/api/auth/register')
      .send({ email, password: 'Test@12345', fullName: 'IT User' });
    expect(res.statusCode).toBe(201);
    expect(res.body.user.role).toBe('student');
    expect(res.body.token).toBeDefined();
  });

  it('rejects duplicate registration with 409', async () => {
    const res = await request(app).post('/api/auth/register')
      .send({ email, password: 'Test@12345', fullName: 'IT User' });
    expect(res.statusCode).toBe(409);
  });

  it('rejects weak input with 400', async () => {
    const res = await request(app).post('/api/auth/register')
      .send({ email: 'bad', password: '1', fullName: '' });
    expect(res.statusCode).toBe(400);
  });

  it('logs in the seeded teacher and /me works', async () => {
    const login = await request(app).post('/api/auth/login')
      .send({ email: 'teacher@assessly.local', password: 'Demo@12345' });
    expect(login.statusCode).toBe(200);
    const me = await request(app).get('/api/auth/me')
      .set('Authorization', `Bearer ${login.body.token}`);
    expect(me.statusCode).toBe(200);
    expect(me.body.user.role).toBe('teacher');
  });

  it('rejects a wrong password with 401', async () => {
    const res = await request(app).post('/api/auth/login')
      .send({ email: 'teacher@assessly.local', password: 'wrong' });
    expect(res.statusCode).toBe(401);
  });

  it('never allows self-registration as teacher', async () => {
    const e2 = `it2_${Date.now()}@assessly.local`;
    const res = await request(app).post('/api/auth/register')
      .send({ email: e2, password: 'Test@12345', fullName: 'Sneaky', role: 'teacher' });
    expect(res.body.user.role).toBe('student');
    await pool.query('DELETE FROM users WHERE email = $1', [e2]);
  });
});
