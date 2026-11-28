'use strict';

const express = require('express');
const { z } = require('zod');
const { query } = require('./db');
const { authenticate, requireRole } = require('./middleware_auth');
const { parseStudentCsv } = require('./csv_import');
const { HttpError, handle } = require('./student_routes').helpers;

const router = express.Router();
router.use(authenticate, requireRole('admin'));

const parse = (schema, body) => {
  const r = schema.safeParse(body);
  if (!r.success) throw new HttpError(400, 'Invalid input', { details: r.error.issues });
  return r.data;
};

/** Maps unique/foreign-key violations to clean 409/404 answers. */
const guard = (fn) => handle(async (req, res) => {
  try {
    await fn(req, res);
  } catch (err) {
    if (err.code === '23505') throw new HttpError(409, 'That name or code already exists');
    if (err.code === '23503') throw new HttpError(404, 'Referenced item not found');
    throw err;
  }
});

// ---------- overview ----------
router.get('/stats', guard(async (req, res) => {
  const n = async (sql) => (await query(sql)).rows[0].n;
  res.json({
    students: await n("SELECT count(*)::int AS n FROM users WHERE role = 'student'"),
    faculty: await n("SELECT count(*)::int AS n FROM users WHERE role = 'teacher'"),
    departments: await n('SELECT count(*)::int AS n FROM departments'),
    courses: await n('SELECT count(*)::int AS n FROM courses'),
    batches: await n('SELECT count(*)::int AS n FROM batches'),
    assessments: await n('SELECT count(*)::int AS n FROM assessments'),
    activeAssessments: await n('SELECT count(*)::int AS n FROM assessments WHERE is_published'),
    submissions: await n("SELECT count(*)::int AS n FROM attempts WHERE status <> 'in_progress'"),
  });
}));

// ---------- departments ----------
const deptSchema = z.object({ name: z.string().min(1).max(150), code: z.string().min(1).max(20) });

router.get('/departments', guard(async (req, res) => {
  const r = await query(
    `SELECT d.*, (SELECT count(*)::int FROM courses c WHERE c.department_id = d.id) AS course_count
     FROM departments d ORDER BY d.name`);
  res.json({ departments: r.rows.map((d) => ({ id: d.id, name: d.name, code: d.code, courseCount: d.course_count })) });
}));

router.post('/departments', guard(async (req, res) => {
  const d = parse(deptSchema, req.body);
  const r = await query('INSERT INTO departments (name, code) VALUES ($1, $2) RETURNING *', [d.name, d.code.toUpperCase()]);
  res.status(201).json({ department: { id: r.rows[0].id, name: r.rows[0].name, code: r.rows[0].code } });
}));

router.put('/departments/:id', guard(async (req, res) => {
  const d = parse(deptSchema, req.body);
  const r = await query('UPDATE departments SET name = $1, code = $2 WHERE id = $3 RETURNING id',
    [d.name, d.code.toUpperCase(), req.params.id]);
  if (!r.rows[0]) throw new HttpError(404, 'Department not found');
  res.json({ updated: true });
}));

router.delete('/departments/:id', guard(async (req, res) => {
  const r = await query('DELETE FROM departments WHERE id = $1', [req.params.id]);
  if (!r.rowCount) throw new HttpError(404, 'Department not found');
  res.status(204).end();
}));

// ---------- courses ----------
const courseSchema = z.object({
  departmentId: z.string().uuid(), name: z.string().min(1).max(150),
  code: z.string().min(1).max(20), semester: z.number().int().min(1).max(12),
});

router.get('/courses', guard(async (req, res) => {
  const r = await query(
    `SELECT c.*, d.name AS department_name FROM courses c JOIN departments d ON d.id = c.department_id
     ORDER BY d.name, c.semester, c.name`);
  res.json({
    courses: r.rows.map((c) => ({
      id: c.id, departmentId: c.department_id, departmentName: c.department_name,
      name: c.name, code: c.code, semester: c.semester,
    })),
  });
}));

router.post('/courses', guard(async (req, res) => {
  const d = parse(courseSchema, req.body);
  const r = await query(
    'INSERT INTO courses (department_id, name, code, semester) VALUES ($1,$2,$3,$4) RETURNING id',
    [d.departmentId, d.name, d.code.toUpperCase(), d.semester]);
  res.status(201).json({ id: r.rows[0].id });
}));

router.delete('/courses/:id', guard(async (req, res) => {
  const r = await query('DELETE FROM courses WHERE id = $1', [req.params.id]);
  if (!r.rowCount) throw new HttpError(404, 'Course not found');
  res.status(204).end();
}));

// ---------- batches ----------
const batchSchema = z.object({
  courseId: z.string().uuid(), name: z.string().min(1).max(100),
  section: z.string().min(1).max(20).default('A'), year: z.number().int().min(2000).max(2100),
});

router.get('/batches', guard(async (req, res) => {
  const r = await query(
    `SELECT b.*, c.name AS course_name, c.code AS course_code,
            (SELECT count(*)::int FROM enrollments e WHERE e.batch_id = b.id) AS student_count
     FROM batches b JOIN courses c ON c.id = b.course_id ORDER BY b.year DESC, c.name, b.name, b.section`);
  res.json({
    batches: r.rows.map((b) => ({
      id: b.id, courseId: b.course_id, courseName: b.course_name, courseCode: b.course_code,
      name: b.name, section: b.section, year: b.year, studentCount: b.student_count,
    })),
  });
}));

router.post('/batches', guard(async (req, res) => {
  const d = parse(batchSchema, req.body);
  const r = await query('INSERT INTO batches (course_id, name, section, year) VALUES ($1,$2,$3,$4) RETURNING id',
    [d.courseId, d.name, d.section, d.year]);
  res.status(201).json({ id: r.rows[0].id });
}));

router.delete('/batches/:id', guard(async (req, res) => {
  const r = await query('DELETE FROM batches WHERE id = $1', [req.params.id]);
  if (!r.rowCount) throw new HttpError(404, 'Batch not found');
  res.status(204).end();
}));

// ---------- enrollment ----------
router.get('/batches/:id/students', guard(async (req, res) => {
  const r = await query(
    `SELECT u.id, u.full_name, u.email, u.roll_number, u.attendance_pct
     FROM enrollments e JOIN users u ON u.id = e.student_id
     WHERE e.batch_id = $1 ORDER BY u.roll_number NULLS LAST, u.email`, [req.params.id]);
  res.json({
    students: r.rows.map((s) => ({
      id: s.id, fullName: s.full_name, email: s.email, rollNumber: s.roll_number, attendancePct: Number(s.attendance_pct),
    })),
  });
}));

router.post('/batches/:id/enroll', guard(async (req, res) => {
  const { studentIds } = parse(z.object({ studentIds: z.array(z.string().uuid()).min(1).max(2000) }), req.body);
  const b = await query('SELECT 1 FROM batches WHERE id = $1', [req.params.id]);
  if (!b.rows[0]) throw new HttpError(404, 'Batch not found');
  const r = await query(
    `INSERT INTO enrollments (batch_id, student_id)
     SELECT $1, u.id FROM users u WHERE u.id = ANY($2::uuid[]) AND u.role = 'student'
     ON CONFLICT DO NOTHING`, [req.params.id, studentIds]);
  res.json({ enrolled: r.rowCount });
}));

router.delete('/batches/:id/students/:studentId', guard(async (req, res) => {
  const r = await query('DELETE FROM enrollments WHERE batch_id = $1 AND student_id = $2', [req.params.id, req.params.studentId]);
  if (!r.rowCount) throw new HttpError(404, 'Enrollment not found');
  res.status(204).end();
}));

// POST /api/admin/batches/:id/import - body { csv }, same format as the teacher import.
// Creates missing students (temporary password shown once) and enrolls everyone in the batch.
router.post('/batches/:id/import', guard(async (req, res) => {
  const { csv } = parse(z.object({ csv: z.string().min(1).max(500000) }), req.body);
  const b = await query('SELECT 1 FROM batches WHERE id = $1', [req.params.id]);
  if (!b.rows[0]) throw new HttpError(404, 'Batch not found');
  const { valid, errors } = parseStudentCsv(csv);
  const bcrypt = require('bcryptjs');
  const temp = require('crypto').randomBytes(9).toString('base64url');
  const hash = await bcrypt.hash(temp, 10);
  const out = { created: 0, updated: 0, enrolled: 0, errors: [...errors] };
  for (const [i, s] of valid.entries()) {
    try {
      const u = await query(
        `INSERT INTO users (email, password_hash, full_name, role, roll_number, attendance_pct)
         VALUES ($1,$2,$3,'student',$4,$5)
         ON CONFLICT (email) DO UPDATE SET full_name = EXCLUDED.full_name,
           roll_number = EXCLUDED.roll_number, attendance_pct = EXCLUDED.attendance_pct
         WHERE users.role = 'student'
         RETURNING id, (xmax = 0) AS inserted`,
        [s.email, hash, s.full_name, s.roll_number, s.attendance_pct]);
      if (!u.rows[0]) { out.errors.push({ line: i + 2, error: 'Email belongs to a non-student account' }); continue; }
      if (u.rows[0].inserted) out.created += 1; else out.updated += 1;
      const e = await query('INSERT INTO enrollments (batch_id, student_id) VALUES ($1,$2) ON CONFLICT DO NOTHING',
        [req.params.id, u.rows[0].id]);
      out.enrolled += e.rowCount;
    } catch (err) {
      if (err.code === '23505') out.errors.push({ line: i + 2, error: 'Roll number already used by another student' });
      else throw err;
    }
  }
  res.json({ ...out, temporaryPassword: out.created ? temp : undefined });
}));

// ---------- users ----------
router.get('/users', guard(async (req, res) => {
  const role = ['student', 'teacher', 'admin'].includes(req.query.role) ? req.query.role : null;
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 50, 1), 200);
  const offset = Math.max(parseInt(req.query.offset, 10) || 0, 0);
  const r = await query(
    `SELECT id, email, full_name, role, roll_number, created_at, count(*) OVER()::int AS total
     FROM users WHERE ($1::user_role IS NULL OR role = $1::user_role)
     ORDER BY created_at DESC LIMIT $2 OFFSET $3`, [role, limit, offset]);
  res.json({
    total: r.rows.length ? r.rows[0].total : 0,
    users: r.rows.map((u) => ({
      id: u.id, email: u.email, fullName: u.full_name, role: u.role, rollNumber: u.roll_number, createdAt: u.created_at,
    })),
  });
}));

const facultySchema = z.object({
  email: z.string().email().max(255), fullName: z.string().min(1).max(150), departmentId: z.string().uuid().optional(),
});

// POST /api/admin/faculty - the only way to create a teacher account; returns a temporary password once.
router.post('/faculty', guard(async (req, res) => {
  const d = parse(facultySchema, req.body);
  const bcrypt = require('bcryptjs');
  const temp = require('crypto').randomBytes(9).toString('base64url');
  const hash = await bcrypt.hash(temp, 10);
  const r = await query(
    `INSERT INTO users (email, password_hash, full_name, role, department_id)
     VALUES ($1,$2,$3,'teacher',$4) RETURNING id`,
    [d.email.toLowerCase(), hash, d.fullName, d.departmentId || null]);
  res.status(201).json({ id: r.rows[0].id, temporaryPassword: temp });
}));

module.exports = router;
