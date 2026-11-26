'use strict';

const express = require('express');
const bcrypt = require('bcryptjs');
const { z } = require('zod');
const { pool, query } = require('./db');
const { authenticate, requireRole } = require('./middleware_auth');
const { parseStudentCsv } = require('./csv_import');
const { summarizeScores } = require('./analytics');

const router = express.Router();
router.use(authenticate, requireRole('teacher'));

class HttpError extends Error {
  constructor(status, message, extra = {}) {
    super(message);
    this.status = status;
    this.extra = extra;
  }
}

const handle = (fn) => async (req, res, next) => {
  try {
    await fn(req, res);
  } catch (err) {
    if (err instanceof HttpError) return res.status(err.status).json({ error: err.message, ...err.extra });
    if (err.code === '22P02') return res.status(400).json({ error: 'Invalid id format' });
    return next(err);
  }
};

const parseBody = (schema, body) => {
  const r = schema.safeParse(body);
  if (!r.success) throw new HttpError(400, 'Invalid input', { details: r.error.issues });
  return r.data;
};

/** Loads an assessment only if it belongs to the calling teacher. */
async function ownAssessment(id, teacherId, client = null) {
  const q = client ? client.query.bind(client) : query;
  const r = await q('SELECT * FROM assessments WHERE id = $1 AND teacher_id = $2', [id, teacherId]);
  if (!r.rows[0]) throw new HttpError(404, 'Assessment not found');
  return r.rows[0];
}

async function hasAttempts(assessmentId) {
  const r = await query('SELECT count(*)::int AS n FROM attempts WHERE assessment_id = $1', [assessmentId]);
  return r.rows[0].n > 0;
}

const assessmentView = (a) => ({
  id: a.id, title: a.title, description: a.description, durationMinutes: a.duration_minutes,
  questionsPerAttempt: a.questions_per_attempt, minAttendancePct: Number(a.min_attendance_pct),
  isPublished: a.is_published, createdAt: a.created_at,
});

// ---------- Assessments ----------
const assessmentSchema = z.object({
  title: z.string().min(1).max(200),
  description: z.string().max(5000).default(''),
  durationMinutes: z.number().int().min(1).max(600),
  questionsPerAttempt: z.number().int().min(1).max(100).default(5),
  minAttendancePct: z.number().min(0).max(100).default(0),
});

router.post('/assessments', handle(async (req, res) => {
  const d = parseBody(assessmentSchema, req.body);
  const r = await query(
    `INSERT INTO assessments (teacher_id, title, description, duration_minutes, questions_per_attempt, min_attendance_pct)
     VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
    [req.user.id, d.title, d.description, d.durationMinutes, d.questionsPerAttempt, d.minAttendancePct]);
  res.status(201).json({ assessment: assessmentView(r.rows[0]) });
}));

router.get('/assessments', handle(async (req, res) => {
  const r = await query(
    `SELECT a.*, (SELECT count(*)::int FROM questions q WHERE q.assessment_id = a.id) AS question_count,
            (SELECT count(*)::int FROM assignments s WHERE s.assessment_id = a.id) AS assigned_count,
            (SELECT count(*)::int FROM attempts t WHERE t.assessment_id = a.id AND t.status <> 'in_progress') AS submitted_count
     FROM assessments a WHERE a.teacher_id = $1 ORDER BY a.created_at DESC`, [req.user.id]);
  res.json({
    assessments: r.rows.map((a) => ({
      ...assessmentView(a), questionCount: a.question_count,
      assignedCount: a.assigned_count, submittedCount: a.submitted_count,
    })),
  });
}));

router.get('/assessments/:id', handle(async (req, res) => {
  res.json({ assessment: assessmentView(await ownAssessment(req.params.id, req.user.id)) });
}));

router.put('/assessments/:id', handle(async (req, res) => {
  await ownAssessment(req.params.id, req.user.id);
  if (await hasAttempts(req.params.id)) throw new HttpError(409, 'Cannot edit: students have already attempted this assessment');
  const d = parseBody(assessmentSchema, req.body);
  const r = await query(
    `UPDATE assessments SET title=$1, description=$2, duration_minutes=$3, questions_per_attempt=$4, min_attendance_pct=$5
     WHERE id=$6 RETURNING *`,
    [d.title, d.description, d.durationMinutes, d.questionsPerAttempt, d.minAttendancePct, req.params.id]);
  res.json({ assessment: assessmentView(r.rows[0]) });
}));

router.post('/assessments/:id/publish', handle(async (req, res) => {
  const a = await ownAssessment(req.params.id, req.user.id);
  const n = (await query('SELECT count(*)::int AS n FROM questions WHERE assessment_id = $1', [a.id])).rows[0].n;
  if (n < a.questions_per_attempt) {
    throw new HttpError(409, `Add at least ${a.questions_per_attempt} questions before publishing (currently ${n})`);
  }
  const r = await query('UPDATE assessments SET is_published = TRUE WHERE id = $1 RETURNING *', [a.id]);
  res.json({ assessment: assessmentView(r.rows[0]) });
}));

router.post('/assessments/:id/unpublish', handle(async (req, res) => {
  await ownAssessment(req.params.id, req.user.id);
  const r = await query('UPDATE assessments SET is_published = FALSE WHERE id = $1 RETURNING *', [req.params.id]);
  res.json({ assessment: assessmentView(r.rows[0]) });
}));

router.delete('/assessments/:id', handle(async (req, res) => {
  await ownAssessment(req.params.id, req.user.id);
  if (await hasAttempts(req.params.id)) throw new HttpError(409, 'Cannot delete: students have already attempted this assessment');
  await query('DELETE FROM assessments WHERE id = $1', [req.params.id]);
  res.status(204).end();
}));

// ---------- Question bank ----------
const questionSchema = z.discriminatedUnion('type', [
  z.object({
    type: z.literal('mcq'),
    prompt: z.string().min(1).max(5000),
    options: z.array(z.string().min(1).max(500)).min(2).max(6),
    correctOption: z.number().int().min(0),
    marks: z.number().int().min(1).max(100).default(1),
  }).refine((q) => q.correctOption < q.options.length, { message: 'correctOption must index into options', path: ['correctOption'] }),
  z.object({
    type: z.literal('coding'),
    prompt: z.string().min(1).max(5000),
    starterCode: z.string().max(10000).default(''),
    marks: z.number().int().min(1).max(100).default(2),
    testCases: z.array(z.object({
      input: z.string().max(5000).default(''),
      expectedOutput: z.string().min(1).max(5000),
      isSample: z.boolean().default(false),
    })).min(1).max(20),
  }),
]);

async function saveQuestion(client, assessmentId, d, questionId = null) {
  let id = questionId;
  if (id) {
    await client.query(
      `UPDATE questions SET type=$1, prompt=$2, options=$3, correct_option=$4, marks=$5, starter_code=$6 WHERE id=$7`,
      [d.type, d.prompt, d.type === 'mcq' ? JSON.stringify(d.options) : null,
        d.type === 'mcq' ? d.correctOption : null, d.marks, d.type === 'coding' ? d.starterCode : null, id]);
    await client.query('DELETE FROM test_cases WHERE question_id = $1', [id]);
  } else {
    id = (await client.query(
      `INSERT INTO questions (assessment_id, type, prompt, options, correct_option, marks, starter_code)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id`,
      [assessmentId, d.type, d.prompt, d.type === 'mcq' ? JSON.stringify(d.options) : null,
        d.type === 'mcq' ? d.correctOption : null, d.marks, d.type === 'coding' ? d.starterCode : null])).rows[0].id;
  }
  if (d.type === 'coding') {
    for (const t of d.testCases) {
      await client.query(
        'INSERT INTO test_cases (question_id, input, expected_output, is_sample) VALUES ($1,$2,$3,$4)',
        [id, t.input, t.expectedOutput, t.isSample]);
    }
  }
  return id;
}

async function inTx(fn) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const out = await fn(client);
    await client.query('COMMIT');
    return out;
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    throw err;
  } finally {
    client.release();
  }
}

router.get('/assessments/:id/questions', handle(async (req, res) => {
  await ownAssessment(req.params.id, req.user.id);
  const qs = (await query('SELECT * FROM questions WHERE assessment_id = $1 ORDER BY created_at', [req.params.id])).rows;
  const tcs = (await query(
    'SELECT * FROM test_cases WHERE question_id = ANY($1::uuid[])', [qs.map((q) => q.id)])).rows;
  res.json({
    questions: qs.map((q) => ({
      id: q.id, type: q.type, prompt: q.prompt, options: q.options, correctOption: q.correct_option,
      marks: q.marks, starterCode: q.starter_code,
      testCases: tcs.filter((t) => t.question_id === q.id)
        .map((t) => ({ id: t.id, input: t.input, expectedOutput: t.expected_output, isSample: t.is_sample })),
    })),
  });
}));

router.post('/assessments/:id/questions', handle(async (req, res) => {
  await ownAssessment(req.params.id, req.user.id);
  if (await hasAttempts(req.params.id)) throw new HttpError(409, 'Cannot change questions: students have already attempted this assessment');
  const d = parseBody(questionSchema, req.body);
  const id = await inTx((c) => saveQuestion(c, req.params.id, d));
  res.status(201).json({ id });
}));

router.put('/assessments/:id/questions/:qid', handle(async (req, res) => {
  await ownAssessment(req.params.id, req.user.id);
  if (await hasAttempts(req.params.id)) throw new HttpError(409, 'Cannot change questions: students have already attempted this assessment');
  const d = parseBody(questionSchema, req.body);
  const exists = await query('SELECT 1 FROM questions WHERE id = $1 AND assessment_id = $2', [req.params.qid, req.params.id]);
  if (!exists.rows[0]) throw new HttpError(404, 'Question not found');
  await inTx((c) => saveQuestion(c, req.params.id, d, req.params.qid));
  res.json({ id: req.params.qid });
}));

router.delete('/assessments/:id/questions/:qid', handle(async (req, res) => {
  await ownAssessment(req.params.id, req.user.id);
  if (await hasAttempts(req.params.id)) throw new HttpError(409, 'Cannot change questions: students have already attempted this assessment');
  const r = await query('DELETE FROM questions WHERE id = $1 AND assessment_id = $2', [req.params.qid, req.params.id]);
  if (!r.rowCount) throw new HttpError(404, 'Question not found');
  res.status(204).end();
}));

// ---------- Students: CSV import and assignment ----------
router.get('/students', handle(async (req, res) => {
  const r = await query(
    `SELECT id, email, full_name, roll_number, attendance_pct FROM users WHERE role = 'student' ORDER BY roll_number NULLS LAST, email`);
  res.json({
    students: r.rows.map((s) => ({
      id: s.id, email: s.email, fullName: s.full_name, rollNumber: s.roll_number, attendancePct: Number(s.attendance_pct),
    })),
  });
}));

// POST /api/teacher/students/import - body: { csv: "email,full_name,roll_number,attendance_pct\n..." }
// Existing students (same email) get their name/roll/attendance updated. New ones get a random temporary password.
router.post('/students/import', handle(async (req, res) => {
  const { csv } = parseBody(z.object({ csv: z.string().min(1).max(500000) }), req.body);
  const { valid, errors } = parseStudentCsv(csv);
  const result = { created: 0, updated: 0, errors: [...errors] };
  const tempPassword = require('crypto').randomBytes(9).toString('base64url');
  const hash = await bcrypt.hash(tempPassword, 10);
  for (const [i, s] of valid.entries()) {
    try {
      const r = await query(
        `INSERT INTO users (email, password_hash, full_name, role, roll_number, attendance_pct)
         VALUES ($1,$2,$3,'student',$4,$5)
         ON CONFLICT (email) DO UPDATE SET full_name = EXCLUDED.full_name,
           roll_number = EXCLUDED.roll_number, attendance_pct = EXCLUDED.attendance_pct
         WHERE users.role = 'student'
         RETURNING (xmax = 0) AS inserted`,
        [s.email, hash, s.full_name, s.roll_number, s.attendance_pct]);
      if (!r.rows[0]) result.errors.push({ line: i + 2, error: 'Email belongs to a non-student account' });
      else if (r.rows[0].inserted) result.created += 1;
      else result.updated += 1;
    } catch (err) {
      if (err.code === '23505') result.errors.push({ line: i + 2, error: 'Roll number already used by another student' });
      else throw err;
    }
  }
  res.json({
    ...result,
    note: result.created ? 'New students share one temporary password, shown once here. Ask them to change it.' : undefined,
    temporaryPassword: result.created ? tempPassword : undefined,
  });
}));

const assignSchema = z.object({
  studentIds: z.array(z.string().uuid()).max(2000).optional(),
  allEligible: z.boolean().optional(),
}).refine((d) => d.studentIds || d.allEligible, { message: 'Provide studentIds or allEligible' });

router.post('/assessments/:id/assign', handle(async (req, res) => {
  const a = await ownAssessment(req.params.id, req.user.id);
  const d = parseBody(assignSchema, req.body);
  let ids = d.studentIds || [];
  if (d.allEligible) {
    const r = await query(
      "SELECT id FROM users WHERE role = 'student' AND attendance_pct >= $1", [a.min_attendance_pct]);
    ids = [...new Set([...ids, ...r.rows.map((x) => x.id)])];
  }
  const r = await query(
    `INSERT INTO assignments (assessment_id, student_id)
     SELECT $1, u.id FROM users u WHERE u.id = ANY($2::uuid[]) AND u.role = 'student'
     ON CONFLICT DO NOTHING`, [a.id, ids]);
  res.json({ assigned: r.rowCount });
}));

router.get('/assessments/:id/assignments', handle(async (req, res) => {
  const a = await ownAssessment(req.params.id, req.user.id);
  const r = await query(
    `SELECT u.id, u.full_name, u.email, u.roll_number, u.attendance_pct,
            t.status AS attempt_status
     FROM assignments s JOIN users u ON u.id = s.student_id
     LEFT JOIN attempts t ON t.assessment_id = s.assessment_id AND t.student_id = s.student_id
     WHERE s.assessment_id = $1 ORDER BY u.roll_number NULLS LAST`, [a.id]);
  res.json({
    assignments: r.rows.map((s) => ({
      studentId: s.id, fullName: s.full_name, email: s.email, rollNumber: s.roll_number,
      attendancePct: Number(s.attendance_pct), eligible: Number(s.attendance_pct) >= Number(a.min_attendance_pct),
      attemptStatus: s.attempt_status || 'not_started',
    })),
  });
}));

// ---------- Submissions and analytics ----------
router.get('/assessments/:id/submissions', handle(async (req, res) => {
  await ownAssessment(req.params.id, req.user.id);
  const r = await query(
    `SELECT t.id, t.status, t.started_at, t.submitted_at, t.score, t.max_score, t.tab_switches,
            u.full_name, u.email, u.roll_number
     FROM attempts t JOIN users u ON u.id = t.student_id
     WHERE t.assessment_id = $1 ORDER BY t.started_at`, [req.params.id]);
  res.json({
    submissions: r.rows.map((s) => ({
      attemptId: s.id, status: s.status, fullName: s.full_name, email: s.email, rollNumber: s.roll_number,
      startedAt: s.started_at, submittedAt: s.submitted_at,
      score: s.score === null ? null : Number(s.score), maxScore: s.max_score === null ? null : Number(s.max_score),
      tabSwitches: s.tab_switches,
    })),
  });
}));

router.get('/assessments/:id/analytics', handle(async (req, res) => {
  await ownAssessment(req.params.id, req.user.id);
  const closed = (await query(
    `SELECT score, max_score FROM attempts WHERE assessment_id = $1 AND status <> 'in_progress'`, [req.params.id])).rows;
  const perQuestion = (await query(
    `SELECT q.id, q.prompt, q.type,
            count(a.*)::int AS answered,
            count(*) FILTER (WHERE a.is_correct)::int AS correct
     FROM questions q
     LEFT JOIN answers a ON a.question_id = q.id
     LEFT JOIN attempts t ON t.id = a.attempt_id AND t.status <> 'in_progress'
     WHERE q.assessment_id = $1 AND q.type = 'mcq' AND (a.attempt_id IS NULL OR t.id IS NOT NULL)
     GROUP BY q.id, q.prompt, q.type ORDER BY q.created_at`, [req.params.id])).rows;
  res.json({
    summary: summarizeScores(closed),
    perQuestion: perQuestion.map((q) => ({
      questionId: q.id, prompt: q.prompt, answered: q.answered, correct: q.correct,
      accuracyPct: q.answered ? Math.round((q.correct / q.answered) * 10000) / 100 : null,
    })),
  });
}));

module.exports = router;
