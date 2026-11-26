'use strict';

// Integration tests for teacher APIs. Needs Postgres, migrated and seeded.
require('dotenv').config({ override: true, quiet: true });
process.env.NODE_ENV = 'test';

const request = require('supertest');
const bcrypt = require('bcryptjs');
const { createApp } = require('../src/app');
const { pool } = require('../src/db');

const app = createApp();
const auth = (t) => ({ Authorization: `Bearer ${t}` });
const stamp = Date.now();
const teacherEmail = `t2d_${stamp}@assessly.local`;
const otherTeacherEmail = `t2d_other_${stamp}@assessly.local`;
const createdStudents = [];
let teacherToken;
let otherToken;
let assessmentId;

async function loginAs(email) {
  const r = await request(app).post('/api/auth/login').send({ email, password: 'Teach@12345' });
  return r.body.token;
}

const mcq = (n, correct = 1) => ({
  type: 'mcq', prompt: `Question ${n}?`, options: ['A', 'B', 'C', 'D'], correctOption: correct, marks: 1,
});

beforeAll(async () => {
  const hash = await bcrypt.hash('Teach@12345', 10);
  for (const e of [teacherEmail, otherTeacherEmail]) {
    await pool.query(
      "INSERT INTO users (email, password_hash, full_name, role) VALUES ($1, $2, 'Test Teacher', 'teacher')", [e, hash]);
  }
  teacherToken = await loginAs(teacherEmail);
  otherToken = await loginAs(otherTeacherEmail);
});

afterAll(async () => {
  await pool.query('DELETE FROM users WHERE email = ANY($1::text[])', [[teacherEmail, otherTeacherEmail]]);
  await pool.query('DELETE FROM users WHERE id = ANY($1::uuid[])', [createdStudents]);
  await pool.end();
});

describe('teacher APIs (integration)', () => {
  it('blocks students from teacher routes (403)', async () => {
    const reg = await request(app).post('/api/auth/register')
      .send({ email: `stu2d_${stamp}@assessly.local`, password: 'Test@12345', fullName: 'Stu' });
    createdStudents.push(reg.body.user.id);
    const res = await request(app).get('/api/teacher/assessments').set(auth(reg.body.token));
    expect(res.statusCode).toBe(403);
  });

  it('creates an assessment and rejects invalid input', async () => {
    const bad = await request(app).post('/api/teacher/assessments').set(auth(teacherToken)).send({ title: '' });
    expect(bad.statusCode).toBe(400);
    const res = await request(app).post('/api/teacher/assessments').set(auth(teacherToken))
      .send({ title: 'Teacher Test Quiz', durationMinutes: 20, questionsPerAttempt: 3, minAttendancePct: 75 });
    expect(res.statusCode).toBe(201);
    assessmentId = res.body.assessment.id;
    expect(res.body.assessment.isPublished).toBe(false);
  });

  it('refuses to publish until there are enough questions', async () => {
    const res = await request(app).post(`/api/teacher/assessments/${assessmentId}/publish`).set(auth(teacherToken));
    expect(res.statusCode).toBe(409);
  });

  it('adds MCQ and coding questions and validates them', async () => {
    const base = `/api/teacher/assessments/${assessmentId}/questions`;
    const badMcq = await request(app).post(base).set(auth(teacherToken))
      .send({ type: 'mcq', prompt: 'x', options: ['A', 'B'], correctOption: 5 });
    expect(badMcq.statusCode).toBe(400);
    for (let i = 1; i <= 3; i += 1) {
      expect((await request(app).post(base).set(auth(teacherToken)).send(mcq(i))).statusCode).toBe(201);
    }
    const coding = await request(app).post(base).set(auth(teacherToken)).send({
      type: 'coding', prompt: 'Print hello', starterCode: '',
      testCases: [{ input: '', expectedOutput: 'hello', isSample: true }, { input: '', expectedOutput: 'hello' }],
    });
    expect(coding.statusCode).toBe(201);
    const list = await request(app).get(base).set(auth(teacherToken));
    expect(list.body.questions).toHaveLength(4);
    expect(list.body.questions.find((q) => q.type === 'coding').testCases).toHaveLength(2);
  });

  it('keeps assessments private between teachers (404)', async () => {
    const res = await request(app).get(`/api/teacher/assessments/${assessmentId}`).set(auth(otherToken));
    expect(res.statusCode).toBe(404);
    const edit = await request(app).post(`/api/teacher/assessments/${assessmentId}/questions`)
      .set(auth(otherToken)).send(mcq(9));
    expect(edit.statusCode).toBe(404);
  });

  it('imports students from CSV, reports bad rows, and updates on re-import', async () => {
    const csv = [
      'email,full_name,roll_number,attendance_pct',
      `a_${stamp}@assessly.local,Alice Import,IMP${stamp}A,90`,
      `b_${stamp}@assessly.local,Bob Import,IMP${stamp}B,60`,
      'broken-email,Nobody,IMPX,80',
    ].join('\n');
    const res = await request(app).post('/api/teacher/students/import').set(auth(teacherToken)).send({ csv });
    expect(res.statusCode).toBe(200);
    expect(res.body.created).toBe(2);
    expect(res.body.errors).toHaveLength(1);
    expect(res.body.temporaryPassword).toBeDefined();

    const again = await request(app).post('/api/teacher/students/import').set(auth(teacherToken)).send({ csv });
    expect(again.body.created).toBe(0);
    expect(again.body.updated).toBe(2);

    const ids = (await pool.query('SELECT id FROM users WHERE email LIKE $1', [`%_${stamp}@assessly.local`])).rows;
    ids.forEach((r) => createdStudents.push(r.id));
  });

  it('assigns only eligible students with allEligible', async () => {
    const res = await request(app).post(`/api/teacher/assessments/${assessmentId}/assign`)
      .set(auth(teacherToken)).send({ allEligible: true });
    expect(res.statusCode).toBe(200);
    const list = await request(app).get(`/api/teacher/assessments/${assessmentId}/assignments`).set(auth(teacherToken));
    const bob = list.body.assignments.find((a) => a.email === `b_${stamp}@assessly.local`);
    const alice = list.body.assignments.find((a) => a.email === `a_${stamp}@assessly.local`);
    expect(alice.eligible).toBe(true);
    expect(bob).toBeUndefined(); // 60% < 75% so allEligible skipped him
  });

  it('publishes, then a student attempt locks question edits and feeds analytics', async () => {
    const pub = await request(app).post(`/api/teacher/assessments/${assessmentId}/publish`).set(auth(teacherToken));
    expect(pub.statusCode).toBe(200);
    expect(pub.body.assessment.isPublished).toBe(true);

    // Import Cara, assign her, then log in with the shared temporary password
    const imp = await request(app).post('/api/teacher/students/import').set(auth(teacherToken)).send({
      csv: `email,full_name,roll_number,attendance_pct\nc_${stamp}@assessly.local,Cara Import,IMP${stamp}C,95`,
    });
    const cEmail = `c_${stamp}@assessly.local`;
    const cId = (await pool.query('SELECT id FROM users WHERE email = $1', [cEmail])).rows[0].id;
    createdStudents.push(cId);
    await request(app).post(`/api/teacher/assessments/${assessmentId}/assign`)
      .set(auth(teacherToken)).send({ studentIds: [cId] });
    const login = await request(app).post('/api/auth/login')
      .send({ email: cEmail, password: imp.body.temporaryPassword });
    expect(login.statusCode).toBe(200);

    const started = await request(app).post(`/api/student/assessments/${assessmentId}/start`).set(auth(login.body.token));
    expect(started.statusCode).toBe(201);
    const attemptId = started.body.attempt.id;
    const submit = await request(app).post(`/api/student/attempts/${attemptId}/submit`).set(auth(login.body.token));
    expect(submit.statusCode).toBe(200);

    const locked = await request(app).post(`/api/teacher/assessments/${assessmentId}/questions`)
      .set(auth(teacherToken)).send(mcq(99));
    expect(locked.statusCode).toBe(409);

    const subs = await request(app).get(`/api/teacher/assessments/${assessmentId}/submissions`).set(auth(teacherToken));
    expect(subs.body.submissions).toHaveLength(1);
    const an = await request(app).get(`/api/teacher/assessments/${assessmentId}/analytics`).set(auth(teacherToken));
    expect(an.statusCode).toBe(200);
    expect(an.body.summary.attempts).toBe(1);
  });
});
