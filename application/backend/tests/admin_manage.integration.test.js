'use strict';

// Admin full-control tests. Needs Postgres migrated and the demo admin/teacher seeded.
require('dotenv').config({ override: true, quiet: true });
process.env.NODE_ENV = 'test';

const request = require('supertest');
const { createApp } = require('../src/app');
const { pool } = require('../src/db');

const app = createApp();
const auth = (t) => ({ Authorization: `Bearer ${t}` });
const stamp = Date.now();
const users = [];
let adminToken;
let teacherToken;
let assessmentId;
let deptId;

beforeAll(async () => {
  const a = await request(app).post('/api/auth/login').send({ email: 'admin@assessly.local', password: 'Demo@12345' });
  const t = await request(app).post('/api/auth/login').send({ email: 'teacher@assessly.local', password: 'Demo@12345' });
  adminToken = a.body.token;
  teacherToken = t.body.token;
});

afterAll(async () => {
  if (assessmentId) await pool.query('DELETE FROM assessments WHERE id = $1', [assessmentId]);
  if (deptId) await pool.query('DELETE FROM departments WHERE id = $1', [deptId]);
  await pool.query('DELETE FROM users WHERE id = ANY($1::uuid[])', [users]);
  await pool.end();
});

describe('admin full control (integration)', () => {
  it('sees assessments created by teachers', async () => {
    const res = await request(app).get('/api/teacher/assessments').set(auth(adminToken));
    expect(res.statusCode).toBe(200);
    expect(res.body.assessments.map((x) => x.title)).toContain('DevOps Fundamentals Quiz');
  });

  it('creates an assessment that other teachers cannot open', async () => {
    const c = await request(app).post('/api/teacher/assessments').set(auth(adminToken))
      .send({ title: `Admin Test ${stamp}`, durationMinutes: 15, questionsPerAttempt: 1, minAttendancePct: 0 });
    expect(c.statusCode).toBe(201);
    assessmentId = c.body.assessment.id;
    expect((await request(app).get(`/api/teacher/assessments/${assessmentId}`).set(auth(adminToken))).statusCode).toBe(200);
    expect((await request(app).get(`/api/teacher/assessments/${assessmentId}`).set(auth(teacherToken))).statusCode).toBe(404);
    const q = await request(app).post(`/api/teacher/assessments/${assessmentId}/questions`).set(auth(adminToken))
      .send({ type: 'truefalse', prompt: 'Admin can add questions', answer: true });
    expect(q.statusCode).toBe(201);
  });

  it('searches students, assigns a whole batch, and edits attendance', async () => {
    const d = await request(app).post('/api/admin/departments').set(auth(adminToken)).send({ name: `AM Dept ${stamp}`, code: `am${stamp}`.slice(0, 12) });
    deptId = d.body.department.id;
    const c = await request(app).post('/api/admin/courses').set(auth(adminToken))
      .send({ departmentId: deptId, name: 'Course', code: 'am1', semester: 1 });
    const b = await request(app).post('/api/admin/batches').set(auth(adminToken))
      .send({ courseId: c.body.id, name: 'AM batch', section: 'A', year: 2026 });
    const csv = ['email,full_name,roll_number,attendance_pct',
      `am1_${stamp}@assessly.local,Am One,AM${stamp}1,90`, `am2_${stamp}@assessly.local,Am Two,AM${stamp}2,80`].join('\n');
    await request(app).post(`/api/admin/batches/${b.body.id}/import`).set(auth(adminToken)).send({ csv });

    const found = await request(app).get(`/api/admin/students?q=${stamp}`).set(auth(adminToken));
    expect(found.body.students).toHaveLength(2);
    found.body.students.forEach((s) => users.push(s.id));

    const first = await request(app).post(`/api/admin/assessments/${assessmentId}/assign-batch`).set(auth(adminToken)).send({ batchId: b.body.id });
    expect(first.body.assigned).toBe(2);
    const again = await request(app).post(`/api/admin/assessments/${assessmentId}/assign-batch`).set(auth(adminToken)).send({ batchId: b.body.id });
    expect(again.body.assigned).toBe(0);
    const list = await request(app).get(`/api/teacher/assessments/${assessmentId}/assignments`).set(auth(adminToken));
    expect(list.body.assignments).toHaveLength(2);

    const att = await request(app).put(`/api/teacher/students/${users[0]}/attendance`).set(auth(adminToken)).send({ attendancePct: 55 });
    expect(att.statusCode).toBe(200);
  });
});
