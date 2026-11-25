-- 001_initial_schema.sql
-- Core schema for Assessly.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TYPE user_role AS ENUM ('student', 'teacher');
CREATE TYPE question_type AS ENUM ('mcq', 'coding');
CREATE TYPE attempt_status AS ENUM ('in_progress', 'submitted', 'expired');

CREATE TABLE users (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email          VARCHAR(255) NOT NULL UNIQUE,
  password_hash  VARCHAR(255) NOT NULL,
  full_name      VARCHAR(150) NOT NULL,
  role           user_role NOT NULL,
  roll_number    VARCHAR(50) UNIQUE,
  attendance_pct NUMERIC(5,2) NOT NULL DEFAULT 100
                 CHECK (attendance_pct BETWEEN 0 AND 100),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE assessments (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title              VARCHAR(200) NOT NULL,
  description        TEXT NOT NULL DEFAULT '',
  duration_minutes   INTEGER NOT NULL CHECK (duration_minutes > 0),
  questions_per_attempt INTEGER NOT NULL DEFAULT 5 CHECK (questions_per_attempt > 0),
  min_attendance_pct NUMERIC(5,2) NOT NULL DEFAULT 0
                     CHECK (min_attendance_pct BETWEEN 0 AND 100),
  is_published       BOOLEAN NOT NULL DEFAULT FALSE,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE questions (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  assessment_id  UUID NOT NULL REFERENCES assessments(id) ON DELETE CASCADE,
  type           question_type NOT NULL,
  prompt         TEXT NOT NULL,
  options        JSONB,            -- MCQ: ["A text","B text",...]
  correct_option INTEGER,          -- MCQ: index into options
  marks          INTEGER NOT NULL DEFAULT 1 CHECK (marks > 0),
  starter_code   TEXT,             -- coding questions
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT mcq_has_options CHECK (
    type <> 'mcq' OR (options IS NOT NULL AND correct_option IS NOT NULL)
  )
);

CREATE TABLE test_cases (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id  UUID NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
  input        TEXT NOT NULL DEFAULT '',
  expected_output TEXT NOT NULL,
  is_sample    BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE assignments (
  assessment_id UUID NOT NULL REFERENCES assessments(id) ON DELETE CASCADE,
  student_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  assigned_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (assessment_id, student_id)
);

CREATE TABLE attempts (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  assessment_id  UUID NOT NULL REFERENCES assessments(id) ON DELETE CASCADE,
  student_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  question_ids   UUID[] NOT NULL,          -- this student's random selection, in order
  started_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  deadline_at    TIMESTAMPTZ NOT NULL,     -- server-side timer
  submitted_at   TIMESTAMPTZ,
  status         attempt_status NOT NULL DEFAULT 'in_progress',
  score          NUMERIC(6,2),
  max_score      NUMERIC(6,2),
  tab_switches   INTEGER NOT NULL DEFAULT 0,
  -- One attempt per student per assessment: prevents duplicate submissions
  UNIQUE (assessment_id, student_id)
);

CREATE TABLE answers (
  attempt_id     UUID NOT NULL REFERENCES attempts(id) ON DELETE CASCADE,
  question_id    UUID NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
  selected_option INTEGER,
  code           TEXT,
  marked_for_review BOOLEAN NOT NULL DEFAULT FALSE,
  is_correct     BOOLEAN,
  marks_awarded  NUMERIC(6,2) NOT NULL DEFAULT 0,
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (attempt_id, question_id)
);

CREATE TABLE code_runs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  attempt_id  UUID NOT NULL REFERENCES attempts(id) ON DELETE CASCADE,
  question_id UUID NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
  kind        VARCHAR(10) NOT NULL CHECK (kind IN ('run', 'submit')),
  passed      INTEGER NOT NULL DEFAULT 0,
  total       INTEGER NOT NULL DEFAULT 0,
  output      TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_questions_assessment ON questions(assessment_id);
CREATE INDEX idx_attempts_student ON attempts(student_id);
CREATE INDEX idx_assignments_student ON assignments(student_id);
