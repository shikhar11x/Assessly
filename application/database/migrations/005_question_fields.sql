-- 005_question_fields.sql
ALTER TABLE questions
  ADD COLUMN correct_options INTEGER[],
  ADD COLUMN correct_text    TEXT,
  ADD COLUMN correct_number  NUMERIC,
  ADD COLUMN tolerance       NUMERIC NOT NULL DEFAULT 0 CHECK (tolerance >= 0),
  ADD COLUMN explanation     TEXT;

ALTER TABLE assessments
  ADD COLUMN negative_marking NUMERIC(5,2) NOT NULL DEFAULT 0 CHECK (negative_marking >= 0),
  ADD COLUMN instructions     TEXT NOT NULL DEFAULT '',
  ADD COLUMN shuffle_options  BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE answers
  ADD COLUMN selected_options INTEGER[],
  ADD COLUMN text_answer      TEXT;

-- the old rule required options for type 'mcq' only, which still holds; relax nothing.
