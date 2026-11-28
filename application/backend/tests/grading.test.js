'use strict';

const { gradeAnswer, floorTotal, isAnswered } = require('../src/grading');

const q = (over) => ({ marks: 2, ...over });

describe('grading: auto types', () => {
  it('mcq and truefalse compare the chosen index', () => {
    expect(gradeAnswer(q({ type: 'mcq', correct_option: 1 }), { selected_option: 1 }).marks).toBe(2);
    expect(gradeAnswer(q({ type: 'truefalse', correct_option: 0 }), { selected_option: 1 }, 0.5).marks).toBe(-0.5);
  });

  it('msq is all-or-nothing and order independent', () => {
    const m = q({ type: 'msq', correct_options: [0, 2] });
    expect(gradeAnswer(m, { selected_options: [2, 0] }).correct).toBe(true);
    expect(gradeAnswer(m, { selected_options: [0] }).correct).toBe(false);
    expect(gradeAnswer(m, { selected_options: [0, 1, 2] }).correct).toBe(false);
  });

  it('fill_blank accepts any listed answer, ignoring case and spacing', () => {
    const f = q({ type: 'fill_blank', correct_text: 'Docker | docker engine' });
    expect(gradeAnswer(f, { text_answer: '  DOCKER ' }).correct).toBe(true);
    expect(gradeAnswer(f, { text_answer: 'Docker   Engine' }).correct).toBe(true);
    expect(gradeAnswer(f, { text_answer: 'podman' }).correct).toBe(false);
  });

  it('numeric uses the tolerance', () => {
    const n = q({ type: 'numeric', correct_number: 3.14, tolerance: 0.01 });
    expect(gradeAnswer(n, { text_answer: '3.145' }).correct).toBe(true);
    expect(gradeAnswer(n, { text_answer: '3.2' }).correct).toBe(false);
    expect(gradeAnswer(n, { text_answer: 'abc' }).answered).toBe(false);
  });
});

describe('grading: negative marking and manual types', () => {
  it('a blank answer is never penalised', () => {
    const r = gradeAnswer(q({ type: 'mcq', correct_option: 1 }), { selected_option: null }, 1);
    expect(r).toMatchObject({ answered: false, marks: 0 });
    expect(gradeAnswer(q({ type: 'mcq', correct_option: 1 }), undefined, 1).marks).toBe(0);
  });

  it('short and long answers are left for a teacher', () => {
    const r = gradeAnswer(q({ type: 'long' }), { text_answer: 'An essay' }, 1);
    expect(r).toEqual({ gradable: false, answered: true, correct: null, marks: 0 });
    expect(isAnswered(q({ type: 'short' }), { text_answer: '' })).toBe(false);
  });

  it('the total never goes below zero', () => {
    expect(floorTotal(-3)).toBe(0);
    expect(floorTotal(2.456)).toBe(2.46);
  });
});
