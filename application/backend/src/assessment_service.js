'use strict';

const crypto = require('crypto');

/** Seconds of tolerance for network delay when a student submits right at the deadline. */
const GRACE_SECONDS = 5;

/** Fisher-Yates shuffle using a cryptographically secure RNG (not Math.random). */
function shuffle(items) {
  const a = [...items];
  for (let i = a.length - 1; i > 0; i -= 1) {
    const j = crypto.randomInt(i + 1);
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

/** Picks n distinct question ids at random (all of them if the bank is smaller). */
function pickQuestions(ids, n) {
  return shuffle(ids).slice(0, Math.min(n, ids.length));
}

function computeDeadline(startedAt, durationMinutes) {
  return new Date(startedAt.getTime() + durationMinutes * 60 * 1000);
}

/** Attendance-based eligibility: student attendance must meet the assessment minimum. */
function isEligible(student, assessment) {
  return Number(student.attendance_pct) >= Number(assessment.min_attendance_pct);
}

function remainingSeconds(deadline, now = new Date()) {
  return Math.max(0, Math.floor((new Date(deadline).getTime() - now.getTime()) / 1000));
}

function isPastDeadline(deadline, now = new Date(), graceSeconds = GRACE_SECONDS) {
  return now.getTime() > new Date(deadline).getTime() + graceSeconds * 1000;
}

/** Grades one MCQ. An unanswered question (null/undefined) scores 0. */
function gradeMcq(question, selectedOption) {
  const answered = selectedOption !== null && selectedOption !== undefined;
  const isCorrect = answered && Number(selectedOption) === question.correct_option;
  return { isCorrect, marks: isCorrect ? question.marks : 0 };
}

module.exports = {
  GRACE_SECONDS, pickQuestions, computeDeadline, isEligible,
  remainingSeconds, isPastDeadline, gradeMcq,
};
