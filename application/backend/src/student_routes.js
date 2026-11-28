'use strict';

const express = require('express');
const { z } = require('zod');
const { pool, query } = require('./db');
const { authenticate, requireRole } = require('./middleware_auth');
const svc = require('./assessment_service');
const grading = require('./grading');

const router = express.Router();
router.use(authenticate, requireRole('student'));

/** Error that carries an HTTP status and optional extra JSON fields. */
class HttpError extends Error {
  constructor(status, message, extra = {}) {
    super(message);
    this.status = status;
    this.extra = extra;
  }
}

/** Wraps async handlers: maps HttpError to JSON, invalid UUIDs to 400, the rest to next(). */
const handle = (fn) => async (req, res, next) => {
  try {
    await fn(req, res);
  } catch (err) {
    if (err instanceof HttpError) return res.status(err.status).json({ error: err.message, ...err.extra });
    if (err.code === '22P02') return res.status(400).json({ error: 'Invalid id format' });
    return next(err);
  }
};

async function withTx(fn) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    throw err;
  } finally {
    client.release();
  }
}

/**
 * Grades and closes an attempt. Locks the row so concurrent submits cannot double-grade.
 * Coding questions are graded by the execution service in a later step (score 0 / pending).
 */
async function finalizeAttempt(client, attemptId, status) {
  const attempt = (await client.query('SELECT * FROM attempts WHERE id = $1 FOR UPDATE', [attemptId])).rows[0];
  if (attempt.status !== 'in_progress') return attempt;

  const questions = (await client.query(
    'SELECT * FROM questions WHERE id = ANY($1::uuid[])', [attempt.question_ids])).rows;
  const answers = (await client.query('SELECT * FROM answers WHERE attempt_id = $1', [attemptId])).rows;
  const byQuestion = new Map(answers.map((a) => [a.question_id, a]));

  const neg = Number((await client.query('SELECT negative_marking FROM assessments WHERE id = $1', [attempt.assessment_id])).rows[0].negative_marking);
  let score = 0;
  let max = 0;
  for (const q of questions) {
    max += q.marks;
    if (['coding', 'short', 'long'].includes(q.type)) {
      const ca = byQuestion.get(q.id);
      if (ca) score += Number(ca.marks_awarded);
      continue;
    }
    const ans = byQuestion.get(q.id);
    const g0 = grading.gradeAnswer(q, ans, neg);
    const g = { isCorrect: g0.correct, marks: g0.marks };
    score += g.marks;
    if (ans) {
      await client.query(
        'UPDATE answers SET is_correct = $1, marks_awarded = $2 WHERE attempt_id = $3 AND question_id = $4',
        [g.isCorrect, g.marks, attemptId, q.id]);
    }
  }
  return (await client.query(
    `UPDATE attempts SET status = $1, submitted_at = now(), score = $2, max_score = $3
     WHERE id = $4 RETURNING *`, [status, grading.floorTotal(score), max, attemptId])).rows[0];
}

async function getOwnAttempt(attemptId, studentId) {
  const r = await query('SELECT * FROM attempts WHERE id = $1 AND student_id = $2', [attemptId, studentId]);
  if (!r.rows[0]) throw new HttpError(404, 'Attempt not found');
  return r.rows[0];
}

/** Closes the attempt automatically if the server-side deadline has passed. */
async function expireIfNeeded(attempt) {
  if (attempt.status === 'in_progress' && svc.isPastDeadline(attempt.deadline_at)) {
    return withTx((c) => finalizeAttempt(c, attempt.id, 'expired'));
  }
  return attempt;
}

function summary(a) {
  return {
    id: a.id,
    assessmentId: a.assessment_id,
    status: a.status,
    startedAt: a.started_at,
    deadlineAt: a.deadline_at,
    remainingSeconds: a.status === 'in_progress' ? svc.remainingSeconds(a.deadline_at) : 0,
    submittedAt: a.submitted_at,
    score: a.score === null ? null : Number(a.score),
    maxScore: a.max_score === null ? null : Number(a.max_score),
    tabSwitches: a.tab_switches,
  };
}

/** Questions for a student's attempt, in their random order. Never includes correct answers. */
async function attemptView(attempt) {
  const qs = (await query(
    `SELECT id, type, prompt, options, marks, starter_code
     FROM questions WHERE id = ANY($1::uuid[])`, [attempt.question_ids])).rows;
  const samples = (await query(
    `SELECT question_id, input, expected_output FROM test_cases
     WHERE question_id = ANY($1::uuid[]) AND is_sample`, [attempt.question_ids])).rows;
  const answers = (await query('SELECT * FROM answers WHERE attempt_id = $1', [attempt.id])).rows;

  const byId = new Map(qs.map((q) => [q.id, q]));
  const questions = attempt.question_ids.map((id) => {
    const q = byId.get(id);
    return {
      id: q.id, type: q.type, prompt: q.prompt, options: q.options, marks: q.marks,
      starterCode: q.starter_code,
      sampleCases: samples.filter((s) => s.question_id === id)
        .map((s) => ({ input: s.input, expectedOutput: s.expected_output })),
    };
  });
  return {
    attempt: summary(attempt),
    questions,
    answers: answers.map((a) => ({
      questionId: a.question_id, selectedOption: a.selected_option, selectedOptions: a.selected_options, textAnswer: a.text_answer,
      code: a.code, markedForReview: a.marked_for_review,
    })),
  };
}

// GET /api/student/assessments - assigned, published assessments with eligibility + attempt state
router.get('/assessments', handle(async (req, res) => {
  const stu = (await query('SELECT attendance_pct FROM users WHERE id = $1', [req.user.id])).rows[0];
  const r = await query(
    `SELECT a.id, a.title, a.description, a.duration_minutes, a.questions_per_attempt,
            a.min_attendance_pct, t.id AS attempt_id, t.status AS attempt_status,
            t.score, t.max_score
     FROM assessments a
     JOIN assignments s ON s.assessment_id = a.id AND s.student_id = $1
     LEFT JOIN attempts t ON t.assessment_id = a.id AND t.student_id = $1
     WHERE a.is_published ORDER BY a.created_at DESC`, [req.user.id]);
  res.json({
    attendancePct: Number(stu.attendance_pct),
    assessments: r.rows.map((a) => ({
      id: a.id, title: a.title, description: a.description,
      durationMinutes: a.duration_minutes, questionsPerAttempt: a.questions_per_attempt,
      minAttendancePct: Number(a.min_attendance_pct),
      eligible: svc.isEligible(stu, a),
      attemptId: a.attempt_id, attemptStatus: a.attempt_status || 'not_started',
      score: a.score === null ? null : Number(a.score),
      maxScore: a.max_score === null ? null : Number(a.max_score),
    })),
  });
}));

// POST /api/student/assessments/:id/start - create the attempt with a random question set
router.post('/assessments/:id/start', handle(async (req, res) => {
  const studentId = req.user.id;
  const attemptId = await withTx(async (c) => {
    const a = (await c.query(
      `SELECT a.* FROM assessments a
       JOIN assignments s ON s.assessment_id = a.id
       WHERE a.id = $1 AND s.student_id = $2 AND a.is_published`, [req.params.id, studentId])).rows[0];
    if (!a) throw new HttpError(404, 'Assessment not found or not assigned to you');

    const stu = (await c.query('SELECT attendance_pct FROM users WHERE id = $1', [studentId])).rows[0];
    if (!svc.isEligible(stu, a)) {
      throw new HttpError(403, `Not eligible: attendance ${Number(stu.attendance_pct)}% is below the required ${Number(a.min_attendance_pct)}%`);
    }

    const existing = (await c.query(
      'SELECT id FROM attempts WHERE assessment_id = $1 AND student_id = $2', [a.id, studentId])).rows[0];
    if (existing) throw new HttpError(409, 'You have already attempted this assessment', { attemptId: existing.id });

    const ids = (await c.query('SELECT id FROM questions WHERE assessment_id = $1', [a.id])).rows.map((r) => r.id);
    if (!ids.length) throw new HttpError(409, 'This assessment has no questions yet');

    const picked = svc.pickQuestions(ids, a.questions_per_attempt);
    const started = new Date();
    const ins = await c.query(
      `INSERT INTO attempts (assessment_id, student_id, question_ids, started_at, deadline_at)
       VALUES ($1, $2, $3, $4, $5) RETURNING id`,
      [a.id, studentId, picked, started, svc.computeDeadline(started, a.duration_minutes)]);
    return ins.rows[0].id;
  }).catch((err) => {
    // Two simultaneous starts: the UNIQUE (assessment_id, student_id) constraint rejects the loser.
    if (err.code === '23505') throw new HttpError(409, 'You have already attempted this assessment');
    throw err;
  });

  const attempt = await getOwnAttempt(attemptId, studentId);
  res.status(201).json(await attemptView(attempt));
}));

// GET /api/student/attempts/:id - resume an attempt (auto-closes it if time ran out)
router.get('/attempts/:id', handle(async (req, res) => {
  let attempt = await getOwnAttempt(req.params.id, req.user.id);
  attempt = await expireIfNeeded(attempt);
  res.json(await attemptView(attempt));
}));

const answerSchema = z.object({
  selectedOption: z.number().int().min(0).nullable().optional(),
  selectedOptions: z.array(z.number().int().min(0)).max(8).nullable().optional(),
  textAnswer: z.string().max(10000).nullable().optional(),
  code: z.string().max(20000).nullable().optional(),
  markedForReview: z.boolean().optional(),
});

// PUT /api/student/attempts/:id/answers/:questionId - save the full answer state for one question
router.put('/attempts/:id/answers/:questionId', handle(async (req, res) => {
  const parsed = answerSchema.safeParse(req.body);
  if (!parsed.success) throw new HttpError(400, 'Invalid input', { details: parsed.error.issues });

  let attempt = await getOwnAttempt(req.params.id, req.user.id);
  if (attempt.status !== 'in_progress') throw new HttpError(409, 'This attempt is already closed');
  if (svc.isPastDeadline(attempt.deadline_at)) {
    await expireIfNeeded(attempt);
    throw new HttpError(409, 'Time is up - the attempt was closed automatically');
  }
  if (!attempt.question_ids.includes(req.params.questionId)) {
    throw new HttpError(404, 'Question is not part of this attempt');
  }

  const q = (await query('SELECT type, options FROM questions WHERE id = $1', [req.params.questionId])).rows[0];
  const { selectedOption = null, selectedOptions = null, textAnswer = null, code = null, markedForReview = false } = parsed.data;
  if (q.type === 'msq' && selectedOptions && selectedOptions.some((i) => i >= q.options.length)) {
    throw new HttpError(400, 'selectedOptions is out of range');
  }
  if (['mcq', 'truefalse'].includes(q.type) && selectedOption !== null && selectedOption >= q.options.length) {
    throw new HttpError(400, 'selectedOption is out of range');
  }

  await query(
    `INSERT INTO answers (attempt_id, question_id, selected_option, code, marked_for_review, selected_options, text_answer, updated_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7, now())
     ON CONFLICT (attempt_id, question_id) DO UPDATE SET
       selected_option = EXCLUDED.selected_option, selected_options = EXCLUDED.selected_options, text_answer = EXCLUDED.text_answer, code = EXCLUDED.code,
       marked_for_review = EXCLUDED.marked_for_review, updated_at = now()`,
    [attempt.id, req.params.questionId, selectedOption, code, markedForReview, selectedOptions, textAnswer]);
  res.json({ saved: true, remainingSeconds: svc.remainingSeconds(attempt.deadline_at) });
}));

// POST /api/student/attempts/:id/tab-switch - record a tab-switch / fullscreen-exit warning
router.post('/attempts/:id/tab-switch', handle(async (req, res) => {
  const r = await query(
    `UPDATE attempts SET tab_switches = tab_switches + 1
     WHERE id = $1 AND student_id = $2 AND status = 'in_progress' RETURNING tab_switches`,
    [req.params.id, req.user.id]);
  if (!r.rows[0]) throw new HttpError(409, 'No active attempt found');
  res.json({ tabSwitches: r.rows[0].tab_switches });
}));

// POST /api/student/attempts/:id/submit - grade and close (works once only)
router.post('/attempts/:id/submit', handle(async (req, res) => {
  const attempt = await getOwnAttempt(req.params.id, req.user.id);
  if (attempt.status !== 'in_progress') throw new HttpError(409, 'This attempt was already submitted');
  const status = svc.isPastDeadline(attempt.deadline_at) ? 'expired' : 'submitted';
  const closed = await withTx((c) => finalizeAttempt(c, attempt.id, status));
  res.json({ attempt: summary(closed), note: 'Coding questions are graded separately.' });
}));

// GET /api/student/attempts/:id/result - breakdown, only after the attempt is closed
router.get('/attempts/:id/result', handle(async (req, res) => {
  let attempt = await getOwnAttempt(req.params.id, req.user.id);
  attempt = await expireIfNeeded(attempt);
  if (attempt.status === 'in_progress') throw new HttpError(409, 'Result is available after submission');
  const qs = (await query(
    `SELECT * FROM questions WHERE id = ANY($1::uuid[])`,
    [attempt.question_ids])).rows;
  const answers = (await query('SELECT * FROM answers WHERE attempt_id = $1', [attempt.id])).rows;
  const byAnswer = new Map(answers.map((a) => [a.question_id, a]));
  const byId = new Map(qs.map((q) => [q.id, q]));
  res.json({
    attempt: summary(attempt),
    breakdown: attempt.question_ids.map((id) => {
      const q = byId.get(id);
      const a = byAnswer.get(id);
      return {
        questionId: id, type: q.type, prompt: q.prompt, marks: q.marks,
        options: q.options,
        correctOption: ['mcq', 'truefalse'].includes(q.type) ? q.correct_option : null,
        correctOptions: q.correct_options, correctText: q.correct_text, correctNumber: q.correct_number === null ? null : Number(q.correct_number), explanation: q.explanation,
        selectedOption: a ? a.selected_option : null, selectedOptions: a ? a.selected_options : null, textAnswer: a ? a.text_answer : null,
        isCorrect: a ? a.is_correct : null,
        marksAwarded: a ? Number(a.marks_awarded) : 0,
        status: q.type === 'coding' ? (a && a.is_correct !== null ? 'graded' : 'no code submitted') : 'graded',
      };
    }),
  });
}));

// GET /api/student/performance - every closed attempt with its score, plus the average
router.get('/performance', handle(async (req, res) => {
  const r = await query(
    `SELECT t.id, a.title, t.status, t.score, t.max_score, t.submitted_at
     FROM attempts t JOIN assessments a ON a.id = t.assessment_id
     WHERE t.student_id = $1 AND t.status <> 'in_progress'
     ORDER BY t.submitted_at DESC`, [req.user.id]);
  const attempts = r.rows.map((x) => {
    const score = x.score === null ? 0 : Number(x.score);
    const max = x.max_score === null ? 0 : Number(x.max_score);
    return {
      attemptId: x.id, title: x.title, status: x.status, score, maxScore: max,
      percentage: max > 0 ? Math.round((score / max) * 10000) / 100 : 0,
      submittedAt: x.submitted_at,
    };
  });
  const avg = attempts.length
    ? Math.round((attempts.reduce((n, a) => n + a.percentage, 0) / attempts.length) * 100) / 100 : 0;
  res.json({ attempts, summary: { count: attempts.length, averagePct: avg } });
}));

module.exports = router;
module.exports.helpers = { HttpError, handle, getOwnAttempt, expireIfNeeded };
