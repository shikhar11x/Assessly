'use strict';

const AUTO_TYPES = ['mcq', 'msq', 'truefalse', 'fill_blank', 'numeric'];
const MANUAL_TYPES = ['short', 'long'];

const norm = (s) => String(s === null || s === undefined ? '' : s).trim().toLowerCase().replace(/\s+/g, ' ');
const sameSet = (a, b) => a.length === b.length && [...a].sort().every((v, i) => v === [...b].sort()[i]);

/** True when the student gave any answer at all (blank answers are never penalised). */
function isAnswered(q, a) {
  if (!a) return false;
  switch (q.type) {
    case 'mcq':
    case 'truefalse': return a.selected_option !== null && a.selected_option !== undefined;
    case 'msq': return Array.isArray(a.selected_options) && a.selected_options.length > 0;
    case 'fill_blank':
    case 'short':
    case 'long': return norm(a.text_answer) !== '';
    case 'numeric': return norm(a.text_answer) !== '' && !Number.isNaN(Number(a.text_answer));
    default: return false;
  }
}

function isCorrect(q, a) {
  switch (q.type) {
    case 'mcq':
    case 'truefalse': return Number(a.selected_option) === q.correct_option;
    case 'msq': return sameSet((a.selected_options || []).map(Number), (q.correct_options || []).map(Number));
    case 'fill_blank': return String(q.correct_text || '').split('|').map(norm).filter(Boolean).includes(norm(a.text_answer));
    case 'numeric': return Math.abs(Number(a.text_answer) - Number(q.correct_number)) <= Number(q.tolerance || 0);
    default: return false;
  }
}

/**
 * Grades one answer. Returns { gradable, answered, correct, marks }.
 * marks = +question marks when correct, -negative when answered wrong, 0 when blank.
 * short / long are not gradable here: they wait for a teacher.
 */
function gradeAnswer(q, a, negative = 0) {
  if (MANUAL_TYPES.includes(q.type)) return { gradable: false, answered: isAnswered(q, a), correct: null, marks: 0 };
  if (!AUTO_TYPES.includes(q.type)) return { gradable: false, answered: false, correct: null, marks: 0 };
  if (!isAnswered(q, a)) return { gradable: true, answered: false, correct: false, marks: 0 };
  if (isCorrect(q, a)) return { gradable: true, answered: true, correct: true, marks: Number(q.marks) };
  return { gradable: true, answered: true, correct: false, marks: -Number(negative) };
}

/** Total never drops below zero. */
const floorTotal = (n) => Math.max(0, Math.round(n * 100) / 100);

module.exports = { AUTO_TYPES, MANUAL_TYPES, isAnswered, isCorrect, gradeAnswer, floorTotal };
