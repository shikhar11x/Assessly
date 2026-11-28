'use strict';

const { z } = require('zod');

const base = { prompt: z.string().min(1).max(5000), marks: z.number().int().min(1).max(100).default(1),
  explanation: z.string().max(2000).optional() };
const options = z.array(z.string().min(1).max(500)).min(2).max(8);

/** Validation for every question type the teacher can create. */
const questionSchemaV2 = z.discriminatedUnion('type', [
  z.object({ ...base, type: z.literal('mcq'), options, correctOption: z.number().int().min(0) })
    .refine((q) => q.correctOption < q.options.length, { message: 'correctOption must index into options', path: ['correctOption'] }),
  z.object({ ...base, type: z.literal('msq'), options, correctOptions: z.array(z.number().int().min(0)).min(1) })
    .refine((q) => q.correctOptions.every((i) => i < q.options.length) && new Set(q.correctOptions).size === q.correctOptions.length,
      { message: 'correctOptions must be distinct indexes into options', path: ['correctOptions'] }),
  z.object({ ...base, type: z.literal('truefalse'), answer: z.boolean() }),
  z.object({ ...base, type: z.literal('fill_blank'), acceptedAnswers: z.array(z.string().min(1).max(200)).min(1).max(10) }),
  z.object({ ...base, type: z.literal('numeric'), correctNumber: z.number(), tolerance: z.number().min(0).default(0) }),
  z.object({ ...base, type: z.literal('short') }),
  z.object({ ...base, type: z.literal('long') }),
  z.object({ ...base, type: z.literal('coding'), starterCode: z.string().max(10000).default(''),
    testCases: z.array(z.object({ input: z.string().max(5000).default(''), expectedOutput: z.string().min(1).max(5000),
      isSample: z.boolean().default(false) })).min(1).max(20) }),
]);

/** Maps a validated question to the columns of the questions table. */
function toRow(d) {
  const row = { type: d.type, prompt: d.prompt, marks: d.marks, explanation: d.explanation || null,
    options: null, correct_option: null, correct_options: null, correct_text: null,
    correct_number: null, tolerance: 0, starter_code: null };
  if (d.type === 'mcq') Object.assign(row, { options: JSON.stringify(d.options), correct_option: d.correctOption });
  if (d.type === 'msq') Object.assign(row, { options: JSON.stringify(d.options), correct_options: d.correctOptions });
  if (d.type === 'truefalse') Object.assign(row, { options: JSON.stringify(['True', 'False']), correct_option: d.answer ? 0 : 1 });
  if (d.type === 'fill_blank') row.correct_text = d.acceptedAnswers.join('|');
  if (d.type === 'numeric') Object.assign(row, { correct_number: d.correctNumber, tolerance: d.tolerance });
  if (d.type === 'coding') row.starter_code = d.starterCode;
  return row;
}

module.exports = { questionSchemaV2, toRow };
