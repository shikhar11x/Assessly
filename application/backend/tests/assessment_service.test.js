'use strict';

const svc = require('../src/assessment_service');

const bank = Array.from({ length: 10 }, (_, i) => `q${i + 1}`);

describe('pickQuestions', () => {
  it('returns 5 distinct ids from a bank of 10', () => {
    const picked = svc.pickQuestions(bank, 5);
    expect(picked).toHaveLength(5);
    expect(new Set(picked).size).toBe(5);
    picked.forEach((id) => expect(bank).toContain(id));
  });

  it('returns the whole bank when it is smaller than n', () => {
    expect(svc.pickQuestions(['a', 'b'], 5)).toHaveLength(2);
  });

  it('produces different selections across runs (randomized)', () => {
    const seen = new Set();
    for (let i = 0; i < 20; i += 1) seen.add(svc.pickQuestions(bank, 5).join(','));
    expect(seen.size).toBeGreaterThan(1);
  });
});

describe('deadline and timer', () => {
  it('computeDeadline adds the duration in minutes', () => {
    const start = new Date('2026-01-01T10:00:00Z');
    expect(svc.computeDeadline(start, 30).toISOString()).toBe('2026-01-01T10:30:00.000Z');
  });

  it('remainingSeconds never goes negative', () => {
    const deadline = new Date('2026-01-01T10:00:00Z');
    expect(svc.remainingSeconds(deadline, new Date('2026-01-01T10:05:00Z'))).toBe(0);
    expect(svc.remainingSeconds(deadline, new Date('2026-01-01T09:59:00Z'))).toBe(60);
  });

  it('isPastDeadline respects the grace period', () => {
    const deadline = new Date('2026-01-01T10:00:00Z');
    expect(svc.isPastDeadline(deadline, new Date('2026-01-01T10:00:03Z'))).toBe(false);
    expect(svc.isPastDeadline(deadline, new Date('2026-01-01T10:00:06Z'))).toBe(true);
  });
});

describe('attendance eligibility', () => {
  it('allows a student exactly at the minimum', () => {
    expect(svc.isEligible({ attendance_pct: '75' }, { min_attendance_pct: '75' })).toBe(true);
  });
  it('blocks a student below the minimum', () => {
    expect(svc.isEligible({ attendance_pct: '60' }, { min_attendance_pct: '75' })).toBe(false);
  });
});

describe('gradeMcq', () => {
  const q = { correct_option: 2, marks: 3 };
  it('awards marks for the correct option', () => {
    expect(svc.gradeMcq(q, 2)).toEqual({ isCorrect: true, marks: 3 });
  });
  it('awards nothing for a wrong or missing answer', () => {
    expect(svc.gradeMcq(q, 1)).toEqual({ isCorrect: false, marks: 0 });
    expect(svc.gradeMcq(q, null)).toEqual({ isCorrect: false, marks: 0 });
  });
});
