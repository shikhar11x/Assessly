'use strict';

const MAX_SHOWN = 2000;

/** Ignores Windows line endings, trailing spaces and trailing blank lines. */
function normalize(text) {
  return String(text === null || text === undefined ? '' : text)
    .replace(/\r\n/g, '\n').split('\n').map((l) => l.replace(/\s+$/, '')).join('\n').replace(/\n+$/, '');
}

function outputsMatch(actual, expected) {
  return normalize(actual) === normalize(expected);
}

const clip = (s) => String(s || '').slice(0, MAX_SHOWN);

/**
 * Runs code against test cases through `runner` and returns per-case verdicts.
 * Hidden cases (is_sample = false) reveal only pass/fail, never input or expected output.
 */
async function judge({ code, cases, runner, timeoutMs = 3000 }) {
  const results = [];
  for (const [i, c] of cases.entries()) {
    const out = await runner({ code, input: c.input, timeoutMs });
    const passed = out.status === 'ok' && outputsMatch(out.stdout, c.expected_output);
    const verdict = passed ? 'passed' : (out.status === 'ok' ? 'wrong_answer' : out.status);
    const r = { index: i + 1, isSample: c.is_sample, passed, verdict };
    if (c.is_sample) {
      Object.assign(r, { input: c.input, expectedOutput: c.expected_output, actual: clip(out.stdout), stderr: clip(out.stderr) });
    }
    results.push(r);
  }
  return { passed: results.filter((r) => r.passed).length, total: results.length, results };
}

/** Partial credit: marks scale with the share of passed test cases. */
function awardMarks(passed, total, marks) {
  if (!total) return 0;
  return Math.round((passed / total) * marks * 100) / 100;
}

module.exports = { normalize, outputsMatch, judge, awardMarks };
