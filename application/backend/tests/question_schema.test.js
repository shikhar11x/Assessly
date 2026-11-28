'use strict';

const { questionSchemaV2, toRow } = require('../src/question_schema');

describe('question schema', () => {
  it('accepts every type and rejects bad indexes', () => {
    expect(questionSchemaV2.safeParse({ type: 'msq', prompt: 'p', options: ['a', 'b', 'c'], correctOptions: [0, 2] }).success).toBe(true);
    expect(questionSchemaV2.safeParse({ type: 'msq', prompt: 'p', options: ['a', 'b'], correctOptions: [0, 5] }).success).toBe(false);
    expect(questionSchemaV2.safeParse({ type: 'msq', prompt: 'p', options: ['a', 'b'], correctOptions: [1, 1] }).success).toBe(false);
    expect(questionSchemaV2.safeParse({ type: 'truefalse', prompt: 'p', answer: true }).success).toBe(true);
    expect(questionSchemaV2.safeParse({ type: 'numeric', prompt: 'p', correctNumber: 2 }).success).toBe(true);
    expect(questionSchemaV2.safeParse({ type: 'essay', prompt: 'p' }).success).toBe(false);
  });

  it('maps rows: true/false becomes fixed options, fill-blank joins answers', () => {
    const tf = toRow(questionSchemaV2.parse({ type: 'truefalse', prompt: 'p', answer: false }));
    expect(JSON.parse(tf.options)).toEqual(['True', 'False']);
    expect(tf.correct_option).toBe(1);
    const fb = toRow(questionSchemaV2.parse({ type: 'fill_blank', prompt: 'p', acceptedAnswers: ['Docker', 'docker engine'] }));
    expect(fb.correct_text).toBe('Docker|docker engine');
    expect(toRow(questionSchemaV2.parse({ type: 'numeric', prompt: 'p', correctNumber: 3.14, tolerance: 0.01 })).tolerance).toBe(0.01);
  });
});
