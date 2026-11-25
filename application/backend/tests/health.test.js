'use strict';

const request = require('supertest');
const { createApp } = require('../src/app');

describe('GET /health', () => {
  const app = createApp();

  it('returns 200 and a healthy status payload', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.service).toBe('assessly-backend');
    expect(typeof res.body.uptimeSeconds).toBe('number');
  });

  it('returns 404 JSON for unknown routes', async () => {
    const res = await request(app).get('/does-not-exist');
    expect(res.statusCode).toBe(404);
    expect(res.body.error).toBe('Not Found');
  });

  it('sets security headers via helmet', async () => {
    const res = await request(app).get('/health');
    expect(res.headers['x-powered-by']).toBeUndefined();
    expect(res.headers['x-content-type-options']).toBe('nosniff');
  });
});
