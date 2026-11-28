'use strict';

// New question types, negative marking and answer saving. Needs Postgres migrated through 005.
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

const QUESTIONS = [
  { type: 'mcq', prompt: 'T mcq', options: ['a', 'b', 'c'], correctOption: 1, marks: 2 },
  { type: 'msq', prompt: 'T msq', options: ['a', 'b', 'c'], correctOptions: [0, 2], marks: 2 },
  { type: 'truefalse', prompt: 'T tf', answer: true, marks: 2 },
  { type: 'fill_blank', prompt: 'T fill', acceptedAnswers: ['Docker', 'docker engine'], marks: 2 },
  { type: 'numeric', prompt: 'T num', correctNumber: 3.14, tolerance: 0.01, marks: 2 },
  { type: 'short', prompt: 'T short', marks: 2 },
];
const MIXED = { 'T mcq': { selectedOption: 1 }, 'T msq': { selectedOptions: [0, 2] }, 'T tf': { selectedOption: 1 },
  'T fill': { textAnswer: ' DOCKER ' }, 'T num': { textAnswer: '3.5' }, 'T short': { textAnswer: 'my answer' } };
const ALL_WRONG = { 'T mcq': { selectedOption: 0 }, 'T msq': { selectedOptions: [1] }, 'T tf': { selectedOption: 1 },
  'T fill': { textAnswer: 'podman' }, 'T num': { textAnswer: '9' }, 'T short': { textAnswer: 'x' } };

async function newStudent() {
  const email = `nq_${Date.now()}_${Math.random().toString(36).slice(2, 8)}@assessly.local`;
  const res = await request(app).post('/api/auth/register').send({ email, password: 'Test@12345', fullName: 'NQ' });
  created.push(res.body.user.id);
  await request(app).post(`/api/teacher/assessments/${assessmentId}/assign`).set(auth(teacherToken))
    .send({ studentIds: [res.body.user.id] });
  return res.body.token;
}

const start = (token) => request(app).post(`/api/student/assessments/${assessmentId}/start`).set(auth(token));

beforeAll(async () => {
  const login = await request(app).post('/api/auth/login').send({ email: 'teacher@assessly.local', password: 'Demo@12345' });
  teacherToken = login.body.token;
  const a = await request(app).post('/api/teacher/assessments').set(auth(teacherToken)).send({
    title: `NQ ${Date.now()}`, durationMinutes: 20, questionsPerAttempt: 6, minAttendancePct: 0,
    negativeMarking: 1, instructions: 'Read carefully.' });
  expect(a.body.assessment.negativeMarking).toBe(1);
  expect(a.body.assessment.instructions).toBe('Read carefully.');
  assessmentId = a.body.assessment.id;
  for (const q of QUESTIONS) {
    const r = await request(app).post(`/api/teacher/assessments/${assessmentId}/questions`).set(auth(teacherToken)).send(q);
    expect(r.statusCode).toBe(201);
  }
  const pub = await request(app).post(`/api/teacher/assessments/${assessmentId}/publish`).set(auth(teacherToken));
  expect(pub.statusCode).toBe(200);
});

afterAll(async () => {
  await pool.query('DELETE FROM assessments WHERE id = $1', [assessmentId]);
  await pool.query('DELETE FROM users WHERE id = ANY($1::uuid[])', [created]);
  await pool.end();
});

async function sit(plan) {
  const token = await newStudent();
  const started = await start(token);
  expect(started.statusCode).toBe(201);
  const attemptId = started.body.attempt.id;
  for (const q of started.body.questions) {
    const r = await request(app).put(`/api/student/attempts/${attemptId}/answers/${q.id}`).set(auth(token)).send(plan[q.prompt]);
    expect(r.statusCode).toBe(200);
  }
  const done = await request(app).post(`/api/student/attempts/${attemptId}/submit`).set(auth(token));
  return { done, started, token, attemptId };
}

describe('new question types (integration)', () => {
  it('grades every type, applies negative marking and leaves short answers pending', async () => {
    const { done, started } = await sit(MIXED);
    expect(JSON.stringify(started.body).toLowerCase()).not.toContain('correct');
    // mcq +2, msq +2, truefalse wrong -1, fill +2, numeric wrong -1, short pending 0 => 4 of 12
    expect(done.body.attempt.score).toBe(4);
    expect(done.body.attempt.maxScore).toBe(12);
  });

  it('never lets the total go below zero', async () => {
    const { done } = await sit(ALL_WRONG);
    expect(done.body.attempt.score).toBe(0);
  });

  it('rejects an out-of-range multiple-select answer', async () => {
    const token = await newStudent();
    const started = await start(token);
    const msq = started.body.questions.find((q) => q.type === 'msq');
    const r = await request(app).put(`/api/student/attempts/${started.body.attempt.id}/answers/${msq.id}`)
      .set(auth(token)).send({ selectedOptions: [9] });
    expect(r.statusCode).toBe(400);
  });
});
