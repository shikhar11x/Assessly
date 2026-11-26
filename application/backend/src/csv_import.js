'use strict';

const { parse } = require('csv-parse/sync');
const { z } = require('zod');

const rowSchema = z.object({
  email: z.string().email().max(255),
  full_name: z.string().min(1).max(150),
  roll_number: z.string().min(1).max(50),
  attendance_pct: z.coerce.number().min(0).max(100).default(100),
});

/**
 * Parses student CSV text. Expected header: email,full_name,roll_number,attendance_pct
 * Returns { valid: [...], errors: [{ line, error }] }. Never throws on bad rows.
 */
function parseStudentCsv(text) {
  let records;
  try {
    records = parse(text, { columns: (h) => h.map((c) => c.trim().toLowerCase()), skip_empty_lines: true, trim: true });
  } catch (err) {
    return { valid: [], errors: [{ line: 0, error: `Malformed CSV: ${err.message}` }] };
  }
  const valid = [];
  const errors = [];
  const seenEmails = new Set();
  const seenRolls = new Set();
  records.forEach((rec, i) => {
    const line = i + 2; // +1 for header, +1 for 1-based
    const parsed = rowSchema.safeParse({ ...rec, attendance_pct: rec.attendance_pct === '' ? undefined : rec.attendance_pct });
    if (!parsed.success) {
      errors.push({ line, error: parsed.error.issues.map((x) => `${x.path.join('.')}: ${x.message}`).join('; ') });
      return;
    }
    const email = parsed.data.email.toLowerCase();
    if (seenEmails.has(email)) { errors.push({ line, error: 'Duplicate email in file' }); return; }
    if (seenRolls.has(parsed.data.roll_number)) { errors.push({ line, error: 'Duplicate roll number in file' }); return; }
    seenEmails.add(email);
    seenRolls.add(parsed.data.roll_number);
    valid.push({ ...parsed.data, email });
  });
  return { valid, errors };
}

module.exports = { parseStudentCsv };
