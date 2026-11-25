'use strict';

/**
 * Seed script: demo teacher, students, one assessment with a 10-question bank.
 * Safe to re-run: it skips if the teacher already exists.
 * DEMO credentials only - never use these in a real deployment.
 */
require('dotenv').config();
const bcrypt = require('bcryptjs');
const { Client } = require('pg');

const DEMO_PASSWORD = process.env.SEED_PASSWORD || 'Demo@12345';

const MCQS = [
  ['Which HTTP method is idempotent and used to replace a resource?', ['POST', 'PUT', 'PATCH', 'CONNECT'], 1],
  ['What does CI stand for in CI/CD?', ['Code Integration', 'Continuous Integration', 'Container Isolation', 'Cloud Infrastructure'], 1],
  ['Which Kubernetes object keeps a desired number of pod replicas running?', ['ConfigMap', 'Ingress', 'Deployment', 'Secret'], 2],
  ['Which command builds a Docker image from a Dockerfile?', ['docker run', 'docker build', 'docker pull', 'docker exec'], 1],
  ['What is the default port of PostgreSQL?', ['3306', '27017', '5432', '6379'], 2],
  ['Which tool scans container images for vulnerabilities?', ['Trivy', 'Terraform', 'Ansible', 'Grafana'], 0],
  ['In Git, which command creates a new branch and switches to it?', ['git branch -d x', 'git checkout -b x', 'git merge x', 'git stash x'], 1],
  ['Which deployment strategy sends a small share of traffic to the new version first?', ['Recreate', 'Canary', 'Big bang', 'Shadow copy'], 1],
];

const CODING = [
  {
    prompt: 'Read two integers (one per line) and print their sum.',
    starter: '# Read input with input()\n',
    cases: [['2\n3\n', '5', true], ['10\n-4\n', '6', false], ['0\n0\n', '0', false]],
  },
  {
    prompt: 'Read an integer n and print the factorial of n.',
    starter: '# Read input with input()\n',
    cases: [['5\n', '120', true], ['0\n', '1', false], ['7\n', '5040', false]],
  },
];

async function seed() {
  const client = new Client({ connectionString: process.env.DATABASE_URL });
  await client.connect();
  try {
    const existing = await client.query("SELECT id FROM users WHERE email = 'teacher@assessly.local'");
    if (existing.rows.length) {
      console.log('Seed data already present - nothing to do.');
      return;
    }
    await client.query('BEGIN');
    const hash = await bcrypt.hash(DEMO_PASSWORD, 10);

    const teacher = (await client.query(
      `INSERT INTO users (email, password_hash, full_name, role)
       VALUES ('teacher@assessly.local', $1, 'Demo Teacher', 'teacher') RETURNING id`, [hash])).rows[0];

    const students = [];
    const names = [['asha', 'Asha Verma', 92], ['ravi', 'Ravi Kumar', 85], ['meera', 'Meera Singh', 60]];
    for (const [i, [handle, name, att]] of names.entries()) {
      const r = await client.query(
        `INSERT INTO users (email, password_hash, full_name, role, roll_number, attendance_pct)
         VALUES ($1, $2, $3, 'student', $4, $5) RETURNING id`,
        [`${handle}@assessly.local`, hash, name, `ROLL00${i + 1}`, att]);
      students.push(r.rows[0].id);
    }

    const assessment = (await client.query(
      `INSERT INTO assessments (teacher_id, title, description, duration_minutes, questions_per_attempt, min_attendance_pct, is_published)
       VALUES ($1, 'DevOps Fundamentals Quiz', 'Random 5 questions from a bank of 10.', 30, 5, 75, TRUE) RETURNING id`,
      [teacher.id])).rows[0];

    for (const [prompt, options, correct] of MCQS) {
      await client.query(
        `INSERT INTO questions (assessment_id, type, prompt, options, correct_option, marks)
         VALUES ($1, 'mcq', $2, $3, $4, 1)`, [assessment.id, prompt, JSON.stringify(options), correct]);
    }
    for (const c of CODING) {
      const q = (await client.query(
        `INSERT INTO questions (assessment_id, type, prompt, starter_code, marks)
         VALUES ($1, 'coding', $2, $3, 2) RETURNING id`, [assessment.id, c.prompt, c.starter])).rows[0];
      for (const [input, expected, sample] of c.cases) {
        await client.query(
          'INSERT INTO test_cases (question_id, input, expected_output, is_sample) VALUES ($1, $2, $3, $4)',
          [q.id, input, expected, sample]);
      }
    }

    for (const sid of students) {
      await client.query('INSERT INTO assignments (assessment_id, student_id) VALUES ($1, $2)', [assessment.id, sid]);
    }
    await client.query('COMMIT');
    console.log('Seeded: 1 teacher, 3 students, 1 assessment, 10 questions.');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    await client.end();
  }
}

seed().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
