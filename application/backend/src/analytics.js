'use strict';

/** Summary statistics for closed attempts. scores: array of { score, max_score }. */
function summarizeScores(rows, passPct = 40) {
  if (!rows.length) return { attempts: 0, average: 0, highest: 0, lowest: 0, passRate: 0 };
  const pcts = rows.map((r) => (Number(r.max_score) > 0 ? (Number(r.score) / Number(r.max_score)) * 100 : 0));
  const scores = rows.map((r) => Number(r.score));
  const round = (n) => Math.round(n * 100) / 100;
  return {
    attempts: rows.length,
    average: round(scores.reduce((a, b) => a + b, 0) / scores.length),
    highest: Math.max(...scores),
    lowest: Math.min(...scores),
    passRate: round((pcts.filter((p) => p >= passPct).length / pcts.length) * 100),
  };
}

module.exports = { summarizeScores };
