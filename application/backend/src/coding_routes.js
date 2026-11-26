'use strict';

const express = require('express');
const { z } = require('zod');
const { query } = require('./db');
const { authenticate, requireRole } = require('./middleware_auth');
const { HttpError, handle, getOwnAttempt, expireIfNeeded } = require('./student_routes').helpers;
const svc = require('./assessment_service');
const executor = require('./executor_client');
const judgeLib = require('./judge');

const router = express.Router();
router.use(authenticate, requireRole('student'));

const MAX_RUNS_PER_10S = 5;
const codeSchema = z.object({ code: z.string().min(1).max(20000) });

/** Shared checks for Run and Submit: ownership, open attempt, deadline, question type, rate limit. */
async function prepare(req) {
  const body = codeSchema.safeParse(req.body);
  if (!body.success) throw new HttpError(400, 'Invalid input', { details: body.error.issues });
  const attempt = await getOwnAttempt(req.params.id, req.user.id);
  if (attempt.status !== 'in_progress') throw new HttpError(409, 'This attempt is already closed');
  if (svc.isPastDeadline(attempt.deadline_at)) {
    await expireIfNeeded(attempt);
    throw new HttpError(409, 'Time is up - the attempt was closed automatically');
  }
  if (!attempt.question_ids.includes(req.params.qid)) throw new HttpError(404, 'Question is not part of this attempt');
  const q = (await query('SELECT id, type, marks FROM questions WHERE id = $1', [req.params.qid])).rows[0];
  if (!q || q.type !== 'coding') throw new HttpError(400, 'This is not a coding question');
  const recent = (await query(
    `SELECT count(*)::int AS n FROM code_runs
     WHERE attempt_id = $1 AND created_at > now() - interval '10 seconds'`, [attempt.id])).rows[0].n;
  if (recent >= MAX_RUNS_PER_10S) throw new HttpError(429, 'Too many runs - wait a few seconds');
  return { attempt, question: q, code: body.data.code };
}

async function execute(code, cases) {
  try {
    return await judgeLib.judge({ code, cases, runner: executor.runCode });
  } catch (err) {
    if (err instanceof executor.ExecutorUnavailable) throw new HttpError(503, err.message);
    throw err;
  }
}

async function recordRun(attemptId, questionId, kind, outcome) {
  await query(
    `INSERT INTO code_runs (attempt_id, question_id, kind, passed, total, output)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [attemptId, questionId, kind, outcome.passed, outcome.total,
      JSON.stringify(outcome.results.map((r) => ({ index: r.index, verdict: r.verdict })))]);
}

async function loadCases(questionId, onlySamples) {
  const r = await query(
    `SELECT input, expected_output, is_sample FROM test_cases
     WHERE question_id = $1 ${onlySamples ? 'AND is_sample' : ''} ORDER BY is_sample DESC, id`, [questionId]);
  return r.rows;
}

// POST /api/student/attempts/:id/questions/:qid/run - sample test case(s) only
router.post('/attempts/:id/questions/:qid/run', handle(async (req, res) => {
  const { attempt, question, code } = await prepare(req);
  const cases = await loadCases(question.id, true);
  if (!cases.length) throw new HttpError(409, 'This question has no sample test case');
  const outcome = await execute(code, cases);
  await recordRun(attempt.id, question.id, 'run', outcome);
  res.json({ kind: 'run', ...outcome });
}));

// POST /api/student/attempts/:id/questions/:qid/submit-code - all test cases, stores marks
router.post('/attempts/:id/questions/:qid/submit-code', handle(async (req, res) => {
  const { attempt, question, code } = await prepare(req);
  const cases = await loadCases(question.id, false);
  if (!cases.length) throw new HttpError(409, 'This question has no test cases');
  const outcome = await execute(code, cases);
  const marksAwarded = judgeLib.awardMarks(outcome.passed, outcome.total, question.marks);
  await query(
    `INSERT INTO answers (attempt_id, question_id, code, is_correct, marks_awarded, updated_at)
     VALUES ($1, $2, $3, $4, $5, now())
     ON CONFLICT (attempt_id, question_id) DO UPDATE SET
       code = EXCLUDED.code, is_correct = EXCLUDED.is_correct,
       marks_awarded = EXCLUDED.marks_awarded, updated_at = now()`,
    [attempt.id, question.id, code, outcome.passed === outcome.total, marksAwarded]);
  await recordRun(attempt.id, question.id, 'submit', outcome);
  res.json({
    kind: 'submit', ...outcome, allPassed: outcome.passed === outcome.total,
    marksAwarded, maxMarks: question.marks,
  });
}));

module.exports = router;
