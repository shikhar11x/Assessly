'use strict';

// Coding API integration tests. Postgres is real; the execution service is mocked.
// (The real sandbox is verified separately by scripts/test-executor.ps1.)
jest.mock('../src/executor_client', () => ({
  ExecutorUnavailable: class ExecutorUnavailable extends Error {},
  runCode: jest.fn(async ({ code, input }) => {
    if (code.includes('LOOP')) return { status: 'timeout', stdout: '', stderr: '', exitCode: null };
    if (code.includes('RAISE')) return { status: 'runtime_error', stdout: '', stderr: 'ZeroDivisionError', exitCode: 1 };
    if (code.includes('WRONG')) return { status: 'ok', stdout: '-999\n', stderr: '', exitCode: 0 };
    const sum = String(input).split(/\s+/).filter(Boolean).map(Number).reduce((a, b) => a + b, 0);
    return { status: 'ok', stdout: `${sum}\n`, stderr: '', exitCode: 0 };
  }),
}));

require('dotenv').config({ override: true, quiet: true });
process.env.NODE_ENV = 'test';

const request = require('supertest');
const executor = require('../src/executor_client');
const { createApp } = require('../src/app');
const { pool } = require('../src/db');

const app = createApp();
const auth = (t) => ({ Authorization: `Bearer ${t}` });
const created = [];
let assessmentId;
let sumQid;

async function makeStudent() {
  const email = `c2e_${Date.now()}_${Math.random().toString(36).slice(2, 8)}@assessly.local`;
  const res = await request(app).post('/api/auth/register').send({ email, password: 'Test@12345', fullName: 'Coder' });
  created.push(res.body.user.id);
  await pool.query('INSERT INTO assignments (assessment_id, student_id) VALUES ($1, $2)', [assessmentId, res.body.user.id]);
  return res.body.token;
}

/** Starts an attempt and forces it to contain the "sum" coding question. */
async function startWithCoding(token) {
  const started = await request(app).post(`/api/student/assessments/${assessmentId}/start`).set(auth(token));
  const ids = started.body.questions.map((q) => q.id);
  if (!ids.includes(sumQid)) ids[0] = sumQid;
  await pool.query('UPDATE attempts SET question_ids = $1::uuid[] WHERE id = $2', [ids, started.body.attempt.id]);
  return { attemptId: started.body.attempt.id, ids };
}

const run = (token, aid, code) => request(app)
  .post(`/api/student/attempts/${aid}/questions/${sumQid}/run`).set(auth(token)).send({ code });
const submitCode = (token, aid, code) => request(app)
  .post(`/api/student/attempts/${aid}/questions/${sumQid}/submit-code`).set(auth(token)).send({ code });

beforeAll(async () => {
  assessmentId = (await pool.query("SELECT id FROM assessments WHERE title = 'DevOps Fundamentals Quiz'")).rows[0].id;
  sumQid = (await pool.query("SELECT id FROM questions WHERE prompt LIKE 'Read two integers%'")).rows[0].id;
});

afterAll(async () => {
  await pool.query('DELETE FROM users WHERE id = ANY($1::uuid[])', [created]);
  await pool.end();
});

describe('coding API (integration)', () => {
  it('Run checks only the sample case', async () => {
    const t = await makeStudent();
    const { attemptId } = await startWithCoding(t);
    const res = await run(t, attemptId, 'print(sum)');
    expect(res.statusCode).toBe(200);
    expect(res.body).toMatchObject({ kind: 'run', passed: 1, total: 1 });
    expect(res.body.results[0].actual.trim()).toBe('5');
  });

  it('Submit checks all cases, awards marks, hides hidden cases, and counts at final submit', async () => {
    const t = await makeStudent();
    const { attemptId } = await startWithCoding(t);
    const res = await submitCode(t, attemptId, 'print(sum)');
    expect(res.statusCode).toBe(200);
    expect(res.body).toMatchObject({ passed: 3, total: 3, allPassed: true, marksAwarded: 2 });
    expect(res.body.results.filter((r) => !r.isSample).every((r) => r.expectedOutput === undefined)).toBe(true);

    const final = await request(app).post(`/api/student/attempts/${attemptId}/submit`).set(auth(t));
    expect(final.statusCode).toBe(200);
    expect(final.body.attempt.score).toBe(2); // only the coding marks, no MCQs answered
  });

  it('awards nothing for a wrong answer', async () => {
    const t = await makeStudent();
    const { attemptId } = await startWithCoding(t);
    const res = await submitCode(t, attemptId, 'WRONG');
    expect(res.body).toMatchObject({ passed: 0, total: 3, allPassed: false, marksAwarded: 0 });
  });

  it('reports a timeout verdict for an infinite loop', async () => {
    const t = await makeStudent();
    const { attemptId } = await startWithCoding(t);
    const res = await run(t, attemptId, 'LOOP');
    expect(res.statusCode).toBe(200);
    expect(res.body.results[0]).toMatchObject({ passed: false, verdict: 'timeout' });
  });

  it('reports a runtime error with its message', async () => {
    const t = await makeStudent();
    const { attemptId } = await startWithCoding(t);
    const res = await run(t, attemptId, 'RAISE');
    expect(res.body.results[0].verdict).toBe('runtime_error');
    expect(res.body.results[0].stderr).toMatch(/ZeroDivision/);
  });

  it('returns 503 when the execution service is down', async () => {
    const t = await makeStudent();
    const { attemptId } = await startWithCoding(t);
    executor.runCode.mockRejectedValueOnce(new executor.ExecutorUnavailable('down'));
    const res = await run(t, attemptId, 'print(sum)');
    expect(res.statusCode).toBe(503);
  });

  it('rejects code for an MCQ question (400)', async () => {
    const t = await makeStudent();
    const { attemptId, ids } = await startWithCoding(t);
    const mcq = (await pool.query("SELECT id FROM questions WHERE id = ANY($1::uuid[]) AND type = 'mcq' LIMIT 1", [ids])).rows[0].id;
    const res = await request(app).post(`/api/student/attempts/${attemptId}/questions/${mcq}/run`)
      .set(auth(t)).send({ code: 'print(1)' });
    expect(res.statusCode).toBe(400);
  });

  it('rejects runs after the deadline (409)', async () => {
    const t = await makeStudent();
    const { attemptId } = await startWithCoding(t);
    await pool.query("UPDATE attempts SET deadline_at = now() - interval '1 minute' WHERE id = $1", [attemptId]);
    expect((await run(t, attemptId, 'print(sum)')).statusCode).toBe(409);
  });

  it('rate-limits rapid runs (429 on the sixth)', async () => {
    const t = await makeStudent();
    const { attemptId } = await startWithCoding(t);
    const codes = [];
    for (let i = 0; i < 6; i += 1) codes.push((await run(t, attemptId, 'print(sum)')).statusCode);
    expect(codes.slice(0, 5).every((c) => c === 200)).toBe(true);
    expect(codes[5]).toBe(429);
  });

  it("does not let another student use someone else's attempt (404)", async () => {
    const owner = await makeStudent();
    const other = await makeStudent();
    const { attemptId } = await startWithCoding(owner);
    expect((await run(other, attemptId, 'print(sum)')).statusCode).toBe(404);
  });
});
