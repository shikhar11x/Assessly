'use strict';

// Admin API integration tests. Needs Postgres migrated (002, 003) and the demo admin seeded.
require('dotenv').config({ override: true, quiet: true });
process.env.NODE_ENV = 'test';

const request = require('supertest');
const { createApp } = require('../src/app');
const { pool } = require('../src/db');

const app = createApp();
const auth = (t) => ({ Authorization: `Bearer ${t}` });
const stamp = Date.now();
const createdUsers = [];
let adminToken;
let deptId;
let courseId;
let batchId;

beforeAll(async () => {
  const login = await request(app).post('/api/auth/login').send({ email: 'admin@assessly.local', password: 'Demo@12345' });
  adminToken = login.body.token;
});

afterAll(async () => {
  if (deptId) await pool.query('DELETE FROM departments WHERE id = $1', [deptId]); // cascades courses and batches
  await pool.query('DELETE FROM users WHERE id = ANY($1::uuid[])', [createdUsers]);
  await pool.end();
});

describe('admin API (integration)', () => {
  it('blocks teachers and students (403) and anonymous users (401)', async () => {
    const t = await request(app).post('/api/auth/login').send({ email: 'teacher@assessly.local', password: 'Demo@12345' });
    expect((await request(app).get('/api/admin/stats').set(auth(t.body.token))).statusCode).toBe(403);
    expect((await request(app).get('/api/admin/stats')).statusCode).toBe(401);
  });

  it('returns platform stats', async () => {
    const res = await request(app).get('/api/admin/stats').set(auth(adminToken));
    expect(res.statusCode).toBe(200);
    expect(res.body.students).toBeGreaterThanOrEqual(3);
    expect(res.body.faculty).toBeGreaterThanOrEqual(1);
  });

  it('creates a department, rejects duplicates, then course and batch', async () => {
    const d = await request(app).post('/api/admin/departments').set(auth(adminToken))
      .send({ name: `Dept ${stamp}`, code: `d${stamp}`.slice(0, 12) });
    expect(d.statusCode).toBe(201);
    deptId = d.body.department.id;
    const dup = await request(app).post('/api/admin/departments').set(auth(adminToken))
      .send({ name: `Dept ${stamp}`, code: 'OTHER' });
    expect(dup.statusCode).toBe(409);

    const c = await request(app).post('/api/admin/courses').set(auth(adminToken))
      .send({ departmentId: deptId, name: 'Data Structures', code: 'cs201', semester: 3 });
    expect(c.statusCode).toBe(201);
    courseId = c.body.id;
    const badSem = await request(app).post('/api/admin/courses').set(auth(adminToken))
      .send({ departmentId: deptId, name: 'X', code: 'x', semester: 99 });
    expect(badSem.statusCode).toBe(400);

    const b = await request(app).post('/api/admin/batches').set(auth(adminToken))
      .send({ courseId, name: 'CSE 2026', section: 'A', year: 2026 });
    expect(b.statusCode).toBe(201);
    batchId = b.body.id;
  });

  it('imports students into the batch by CSV and lists them', async () => {
    const csv = ['email,full_name,roll_number,attendance_pct',
      `ad1_${stamp}@assessly.local,Admin One,ADM${stamp}1,90`,
      `ad2_${stamp}@assessly.local,Admin Two,ADM${stamp}2,80`].join('\n');
    const res = await request(app).post(`/api/admin/batches/${batchId}/import`).set(auth(adminToken)).send({ csv });
    expect(res.statusCode).toBe(200);
    expect(res.body).toMatchObject({ created: 2, enrolled: 2 });
    expect(res.body.temporaryPassword).toBeDefined();
    const list = await request(app).get(`/api/admin/batches/${batchId}/students`).set(auth(adminToken));
    expect(list.body.students).toHaveLength(2);
    const ids = (await pool.query('SELECT id FROM users WHERE email LIKE $1', [`ad%_${stamp}@assessly.local`])).rows;
    ids.forEach((r) => createdUsers.push(r.id));
  });

  it('enrolls an existing student once and unenrolls', async () => {
    const asha = (await pool.query("SELECT id FROM users WHERE email = 'asha@assessly.local'")).rows[0].id;
    const a = await request(app).post(`/api/admin/batches/${batchId}/enroll`).set(auth(adminToken)).send({ studentIds: [asha] });
    expect(a.body.enrolled).toBe(1);
    const again = await request(app).post(`/api/admin/batches/${batchId}/enroll`).set(auth(adminToken)).send({ studentIds: [asha] });
    expect(again.body.enrolled).toBe(0);
    expect((await request(app).delete(`/api/admin/batches/${batchId}/students/${asha}`).set(auth(adminToken))).statusCode).toBe(204);
  });

  it('creates a faculty account that can log in, and pages the user list', async () => {
    const res = await request(app).post('/api/admin/faculty').set(auth(adminToken))
      .send({ email: `fac_${stamp}@assessly.local`, fullName: 'New Faculty', departmentId: deptId });
    expect(res.statusCode).toBe(201);
    createdUsers.push(res.body.id);
    const login = await request(app).post('/api/auth/login')
      .send({ email: `fac_${stamp}@assessly.local`, password: res.body.temporaryPassword });
    expect(login.statusCode).toBe(200);
    expect(login.body.user.role).toBe('teacher');
    const page = await request(app).get('/api/admin/users?role=teacher&limit=1').set(auth(adminToken));
    expect(page.body.users).toHaveLength(1);
    expect(page.body.total).toBeGreaterThanOrEqual(2);
  });

  it('deleting a department cascades to its courses and batches', async () => {
    expect((await request(app).delete(`/api/admin/departments/${deptId}`).set(auth(adminToken))).statusCode).toBe(204);
    const left = await pool.query('SELECT count(*)::int AS n FROM batches WHERE id = $1', [batchId]);
    expect(left.rows[0].n).toBe(0);
    deptId = null;
  });
});
