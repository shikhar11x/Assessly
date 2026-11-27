'use strict';

/** Escapes one CSV cell. Cells starting with = + - @ are prefixed so Excel cannot run them as formulas. */
function cell(v) {
  let s = v === null || v === undefined ? '' : String(v);
  if (/^[=+\-@\t\r]/.test(s)) s = `'${s}`;
  if (/[",\n\r]/.test(s)) s = `"${s.replace(/"/g, '""')}"`;
  return s;
}

function toCsv(header, rows) {
  return `${[header, ...rows].map((r) => r.map(cell).join(',')).join('\n')}\n`;
}

module.exports = { cell, toCsv };
