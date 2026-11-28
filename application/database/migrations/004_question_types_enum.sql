-- 004_question_types_enum.sql
ALTER TYPE question_type ADD VALUE IF NOT EXISTS 'msq';
ALTER TYPE question_type ADD VALUE IF NOT EXISTS 'truefalse';
ALTER TYPE question_type ADD VALUE IF NOT EXISTS 'fill_blank';
ALTER TYPE question_type ADD VALUE IF NOT EXISTS 'numeric';
ALTER TYPE question_type ADD VALUE IF NOT EXISTS 'short';
ALTER TYPE question_type ADD VALUE IF NOT EXISTS 'long';
