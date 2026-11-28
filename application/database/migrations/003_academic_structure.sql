-- 003_academic_structure.sql
CREATE TABLE departments (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name       VARCHAR(150) NOT NULL UNIQUE,
  code       VARCHAR(20)  NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE courses (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  department_id UUID NOT NULL REFERENCES departments(id) ON DELETE CASCADE,
  name          VARCHAR(150) NOT NULL,
  code          VARCHAR(20)  NOT NULL,
  semester      INTEGER NOT NULL CHECK (semester BETWEEN 1 AND 12),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (department_id, code)
);

CREATE TABLE batches (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id  UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  name       VARCHAR(100) NOT NULL,
  section    VARCHAR(20)  NOT NULL DEFAULT 'A',
  year       INTEGER NOT NULL CHECK (year BETWEEN 2000 AND 2100),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (course_id, name, section, year)
);

CREATE TABLE enrollments (
  batch_id    UUID NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
  student_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  enrolled_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (batch_id, student_id)
);

CREATE INDEX idx_courses_department ON courses(department_id);
CREATE INDEX idx_batches_course ON batches(course_id);
CREATE INDEX idx_enrollments_student ON enrollments(student_id);

ALTER TABLE users ADD COLUMN department_id UUID REFERENCES departments(id) ON DELETE SET NULL;
