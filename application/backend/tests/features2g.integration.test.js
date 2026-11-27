'use strict';

// Integration tests for the 2g features. Needs Postgres, migrated and seeded.
require('dotenv').config({ override: true, quiet: true });
process.env.NODE_ENV = 'test';

const request = require('supertest');
const { createApp } = require('../src/app');
const { pool } = require('../src/db');

const app = createApp();
const auth = (t) => ({ Authorization: `Bearer ${t}` });
const created = [];
let teacherToken;
let assessmentId;

async function makeStudent(assign = true) {
  const email = `g2_${Date.now()}_${Math.random().toString(36).slice(2, 8)}@assessly.local`;
  const res = await request(app).post('/api/auth/register')
    .send({ email, password: 'Test@12345', fullName: 'G2 Test' });
  created.push(res.body.user.id);
  if (assign) {
    await pool.query('INSERT INTO assignments (assessment_id, student_id) VALUES ($1, $2)', [assessmentId, res.body.user.id]);
  }
  return { token: res.body.token, id: res.body.user.id, email };
}

const startAndSubmit = async (s) => {
  const st = await request(app).post(`/api/student/assessments/${assessmentId}/start`).set(auth(s.token));
  const attemptId = st.body.attempt.id;
  await request(app).post(`/api/student/attempts/${attemptId}/submit`).set(auth(s.token));
  return attemptId;
};

beforeAll(async () => {
  const login = await request(app).post('/api/auth/login')
    .send({ email: 'teacher@assessly.local', password: 'Demo@12345' });
  teacherToken = login.body.token;
  assessmentId = (await pool.query("SELECT id FROM assessments WHERE title = 'DevOps Fundamentals Quiz'")).rows[0].id;
});

afterAll(async () => {
  await pool.query('DELETE FROM users WHERE id = ANY($1::uuid[])', [created]);
  await pool.end();
});

describe('change password', () => {
  it('rejects a wrong current password, then changes it', async () => {
    const s = await makeStudent(false);
    const bad = await request(app).post('/api/auth/change-password').set(auth(s.token))
      .send({ currentPassword: 'nope', newPassword: 'Brand@New123' });
    expect(bad.statusCode).toBe(401);
    const ok = await request(app).post('/api/auth/change-password').set(auth(s.token))
      .send({ currentPassword: 'Test@12345', newPassword: 'Brand@New123' });
    expect(ok.statusCode).toBe(200);
    const oldLogin = await request(app).post('/api/auth/login').send({ email: s.email, password: 'Test@12345' });
    const newLogin = await request(app).post('/api/auth/login').send({ email: s.email, password: 'Brand@New123' });
    expect(oldLogin.statusCode).toBe(401);
    expect(newLogin.statusCode).toBe(200);
  });
});

describe('student performance', () => {
  it('lists closed attempts with percentage and average', async () => {
    const s = await makeStudent();
    await startAndSubmit(s);
    const res = await request(app).get('/api/student/performance').set(auth(s.token));
    expect(res.statusCode).toBe(200);
    expect(res.body.attempts).toHaveLength(1);
    expect(res.body.attempts[0].title).toBe('DevOps Fundamentals Quiz');
    expect(res.body.summary.count).toBe(1);
  });
});

describe('teacher tools', () => {
  it('updates attendance and validates the range', async () => {
    const s = await makeStudent(false);
    const ok = await request(app).put(`/api/teacher/students/${s.id}/attendance`).set(auth(teacherToken)).send({ attendancePct: 50 });
    expect(ok.statusCode).toBe(200);
    const row = await pool.query('SELECT attendance_pct FROM users WHERE id = $1', [s.id]);
    expect(Number(row.rows[0].attendance_pct)).toBe(50);
    const bad = await request(app).put(`/api/teacher/students/${s.id}/attendance`).set(auth(teacherToken)).send({ attendancePct: 150 });
    expect(bad.statusCode).toBe(400);
  });

  it('unassigns before an attempt, but not after', async () => {
    const a = await makeStudent();
    const b = await makeStudent();
    await startAndSubmit(b);
    const base = `/api/teacher/assessments/${assessmentId}/assign`;
    expect((await request(app).delete(`${base}/${a.id}`).set(auth(teacherToken))).statusCode).toBe(200);
    expect((await request(app).delete(`${base}/${a.id}`).set(auth(teacherToken))).statusCode).toBe(404);
    expect((await request(app).delete(`${base}/${b.id}`).set(auth(teacherToken))).statusCode).toBe(409);
  });

  it('shows one attempt in detail and exports results as CSV', async () => {
    const s = await makeStudent();
    const attemptId = await startAndSubmit(s);
    const detail = await request(app)
      .get(`/api/teacher/assessments/${assessmentId}/submissions/${attemptId}`).set(auth(teacherToken));
    expect(detail.statusCode).toBe(200);
    expect(detail.body.student.email).toBe(s.email);
    expect(detail.body.breakdown).toHaveLength(5);

    const exp = await request(app).get(`/api/teacher/assessments/${assessmentId}/results-export`).set(auth(teacherToken));
    expect(exp.statusCode).toBe(200);
    expect(exp.body.csv.startsWith('roll_number,full_name,email')).toBe(true);
    expect(exp.body.csv).toContain(s.email);
    expect(exp.body.filename).toMatch(/\.csv$/);
  });
});
