'use strict';

// Integration tests for the assessment engine. Needs the Postgres container, migrated and seeded.
require('dotenv').config({ override: true, quiet: true });
process.env.NODE_ENV = 'test';

const request = require('supertest');
const { createApp } = require('../src/app');
const { pool } = require('../src/db');

const app = createApp();
const created = [];
let assessmentId;

const auth = (token) => ({ Authorization: `Bearer ${token}` });

async function makeStudent({ attendance = 100, assign = true } = {}) {
  const email = `s2c_${Date.now()}_${Math.random().toString(36).slice(2, 8)}@assessly.local`;
  const res = await request(app).post('/api/auth/register')
    .send({ email, password: 'Test@12345', fullName: 'Engine Test' });
  const { token, user } = res.body;
  created.push(user.id);
  await pool.query('UPDATE users SET attendance_pct = $1 WHERE id = $2', [attendance, user.id]);
  if (assign) {
    await pool.query('INSERT INTO assignments (assessment_id, student_id) VALUES ($1, $2)', [assessmentId, user.id]);
  }
  return { token, id: user.id };
}

const start = (token) => request(app).post(`/api/student/assessments/${assessmentId}/start`).set(auth(token));

beforeAll(async () => {
  const r = await pool.query("SELECT id FROM assessments WHERE title = 'DevOps Fundamentals Quiz'");
  assessmentId = r.rows[0].id;
});

afterAll(async () => {
  await pool.query('DELETE FROM users WHERE id = ANY($1::uuid[])', [created]);
  await pool.end();
});

describe('assessment engine (integration)', () => {
  it('lists the assigned assessment as eligible', async () => {
    const s = await makeStudent();
    const res = await request(app).get('/api/student/assessments').set(auth(s.token));
    expect(res.statusCode).toBe(200);
    const item = res.body.assessments.find((a) => a.id === assessmentId);
    expect(item.eligible).toBe(true);
    expect(item.attemptStatus).toBe('not_started');
  });

  it('starts an attempt with 5 distinct questions and leaks no answers', async () => {
    const s = await makeStudent();
    const res = await start(s.token);
    expect(res.statusCode).toBe(201);
    const ids = res.body.questions.map((q) => q.id);
    expect(ids).toHaveLength(5);
    expect(new Set(ids).size).toBe(5);
    const raw = JSON.stringify(res.body).toLowerCase();
    expect(raw).not.toContain('correct_option');
    expect(raw).not.toContain('correctoption');
    expect(res.body.attempt.remainingSeconds).toBeGreaterThan(1700);
    expect(res.body.attempt.remainingSeconds).toBeLessThanOrEqual(1800);
  });

  it('blocks a duplicate attempt with 409', async () => {
    const s = await makeStudent();
    expect((await start(s.token)).statusCode).toBe(201);
    const again = await start(s.token);
    expect(again.statusCode).toBe(409);
    expect(again.body.attemptId).toBeDefined();
  });

  it('creates only one attempt when two starts arrive at the same time', async () => {
    const s = await makeStudent();
    const results = await Promise.all([start(s.token), start(s.token)]);
    expect(results.map((r) => r.statusCode).sort()).toEqual([201, 409]);
    const count = await pool.query('SELECT count(*)::int AS n FROM attempts WHERE student_id = $1', [s.id]);
    expect(count.rows[0].n).toBe(1);
  });

  it('blocks a student below the attendance minimum with 403', async () => {
    const s = await makeStudent({ attendance: 60 });
    const res = await start(s.token);
    expect(res.statusCode).toBe(403);
    expect(res.body.error).toMatch(/attendance/i);
  });

  it('returns 404 for a student who was not assigned', async () => {
    const s = await makeStudent({ assign: false });
    expect((await start(s.token)).statusCode).toBe(404);
  });

  it('does not let a teacher start an attempt (403)', async () => {
    const login = await request(app).post('/api/auth/login')
      .send({ email: 'teacher@assessly.local', password: 'Demo@12345' });
    expect((await start(login.body.token)).statusCode).toBe(403);
  });

  it('saves answers, resumes them, submits and grades MCQs correctly', async () => {
    const s = await makeStudent();
    const started = await start(s.token);
    const attemptId = started.body.attempt.id;
    const ids = started.body.questions.map((q) => q.id);

    const mcq = (await pool.query(
      `SELECT id, correct_option, marks FROM questions
       WHERE id = ANY($1::uuid[]) AND type = 'mcq'`, [ids])).rows;
    expect(mcq.length).toBeGreaterThanOrEqual(3);

    let expected = 0;
    for (const [i, q] of mcq.entries()) {
      const wrong = i === 0; // answer the first one wrong on purpose
      const selected = wrong ? (q.correct_option + 1) % 4 : q.correct_option;
      if (!wrong) expected += q.marks;
      const save = await request(app)
        .put(`/api/student/attempts/${attemptId}/answers/${q.id}`).set(auth(s.token))
        .send({ selectedOption: selected, markedForReview: wrong });
      expect(save.statusCode).toBe(200);
    }

    const resumed = await request(app).get(`/api/student/attempts/${attemptId}`).set(auth(s.token));
    expect(resumed.body.answers).toHaveLength(mcq.length);
    expect(resumed.body.answers.some((a) => a.markedForReview)).toBe(true);

    const submit = await request(app).post(`/api/student/attempts/${attemptId}/submit`).set(auth(s.token));
    expect(submit.statusCode).toBe(200);
    expect(submit.body.attempt.status).toBe('submitted');
    expect(submit.body.attempt.score).toBe(expected);

    const result = await request(app).get(`/api/student/attempts/${attemptId}/result`).set(auth(s.token));
    expect(result.statusCode).toBe(200);
    expect(result.body.breakdown).toHaveLength(5);
  });

  it('rejects a second submit and any save after submit (409)', async () => {
    const s = await makeStudent();
    const started = await start(s.token);
    const attemptId = started.body.attempt.id;
    const qid = started.body.questions[0].id;
    expect((await request(app).post(`/api/student/attempts/${attemptId}/submit`).set(auth(s.token))).statusCode).toBe(200);
    expect((await request(app).post(`/api/student/attempts/${attemptId}/submit`).set(auth(s.token))).statusCode).toBe(409);
    const save = await request(app).put(`/api/student/attempts/${attemptId}/answers/${qid}`)
      .set(auth(s.token)).send({ selectedOption: 0 });
    expect(save.statusCode).toBe(409);
  });

  it('enforces the server-side timer: late saves are rejected and the attempt expires', async () => {
    const s = await makeStudent();
    const started = await start(s.token);
    const attemptId = started.body.attempt.id;
    const qid = started.body.questions[0].id;
    await pool.query("UPDATE attempts SET deadline_at = now() - interval '1 minute' WHERE id = $1", [attemptId]);
    const save = await request(app).put(`/api/student/attempts/${attemptId}/answers/${qid}`)
      .set(auth(s.token)).send({ selectedOption: 0 });
    expect(save.statusCode).toBe(409);
    const view = await request(app).get(`/api/student/attempts/${attemptId}`).set(auth(s.token));
    expect(view.body.attempt.status).toBe('expired');
  });
});
