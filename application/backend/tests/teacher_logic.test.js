'use strict';

const { parseStudentCsv } = require('../src/csv_import');
const { summarizeScores } = require('../src/analytics');

describe('parseStudentCsv', () => {
  const header = 'email,full_name,roll_number,attendance_pct\n';

  it('parses valid rows and lowercases emails', () => {
    const r = parseStudentCsv(`${header}A@x.com,Alice,R1,90\nb@x.com,Bob,R2,80`);
    expect(r.errors).toHaveLength(0);
    expect(r.valid).toHaveLength(2);
    expect(r.valid[0].email).toBe('a@x.com');
    expect(r.valid[0].attendance_pct).toBe(90);
  });

  it('defaults attendance to 100 when blank', () => {
    const r = parseStudentCsv(`${header}a@x.com,Alice,R1,`);
    expect(r.valid[0].attendance_pct).toBe(100);
  });

  it('reports invalid rows with line numbers and keeps the good ones', () => {
    const r = parseStudentCsv(`${header}not-an-email,Alice,R1,90\nok@x.com,Bob,R2,150\ngood@x.com,Cara,R3,70`);
    expect(r.valid).toHaveLength(1);
    expect(r.errors.map((e) => e.line)).toEqual([2, 3]);
  });

  it('flags duplicate emails and roll numbers inside the file', () => {
    const r = parseStudentCsv(`${header}a@x.com,A,R1,90\na@x.com,B,R2,90\nc@x.com,C,R1,90`);
    expect(r.valid).toHaveLength(1);
    expect(r.errors).toHaveLength(2);
  });

  it('handles a malformed CSV without throwing', () => {
    const r = parseStudentCsv('email,full_name\n"unclosed,quote');
    expect(r.valid).toHaveLength(0);
    expect(r.errors.length).toBeGreaterThan(0);
  });
});

describe('summarizeScores', () => {
  it('returns zeros for no attempts', () => {
    expect(summarizeScores([])).toEqual({ attempts: 0, average: 0, highest: 0, lowest: 0, passRate: 0 });
  });

  it('computes average, highest, lowest and pass rate', () => {
    const r = summarizeScores([
      { score: 5, max_score: 5 }, { score: 3, max_score: 5 }, { score: 1, max_score: 5 },
    ]);
    expect(r.attempts).toBe(3);
    expect(r.average).toBe(3);
    expect(r.highest).toBe(5);
    expect(r.lowest).toBe(1);
    expect(r.passRate).toBe(66.67); // 100% and 60% pass at 40%, 20% fails
  });
});
