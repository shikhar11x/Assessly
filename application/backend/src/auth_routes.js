'use strict';

const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { z } = require('zod');
const config = require('./config');
const db = require('./db');
const { authenticate } = require('./middleware_auth');

const router = express.Router();

const registerSchema = z.object({
  email: z.string().email().max(255),
  password: z.string().min(8).max(100),
  fullName: z.string().min(1).max(150),
  rollNumber: z.string().min(1).max(50).optional(),
});
const loginSchema = z.object({ email: z.string().email(), password: z.string().min(1) });

function signToken(user) {
  return jwt.sign({ role: user.role }, config.jwtSecret, {
    subject: user.id,
    expiresIn: config.jwtExpiresIn,
  });
}

function publicUser(u) {
  return { id: u.id, email: u.email, fullName: u.full_name, role: u.role, rollNumber: u.roll_number };
}

// POST /api/auth/register - student self-registration only
router.post('/register', async (req, res, next) => {
  try {
    const parsed = registerSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: 'Invalid input', details: parsed.error.issues });
    const { email, password, fullName, rollNumber } = parsed.data;
    const hash = await bcrypt.hash(password, 10);
    try {
      const r = await db.query(
        `INSERT INTO users (email, password_hash, full_name, role, roll_number)
         VALUES ($1, $2, $3, 'student', $4) RETURNING *`,
        [email.toLowerCase(), hash, fullName, rollNumber || null]);
      const user = r.rows[0];
      return res.status(201).json({ token: signToken(user), user: publicUser(user) });
    } catch (err) {
      if (err.code === '23505') return res.status(409).json({ error: 'Email or roll number already registered' });
      throw err;
    }
  } catch (err) { return next(err); }
});

// POST /api/auth/login
router.post('/login', async (req, res, next) => {
  try {
    const parsed = loginSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: 'Invalid input' });
    const r = await db.query('SELECT * FROM users WHERE email = $1', [parsed.data.email.toLowerCase()]);
    const user = r.rows[0];
    // Same message for unknown email and wrong password: avoids leaking which emails exist.
    const ok = user && (await bcrypt.compare(parsed.data.password, user.password_hash));
    if (!ok) return res.status(401).json({ error: 'Invalid email or password' });
    return res.json({ token: signToken(user), user: publicUser(user) });
  } catch (err) { return next(err); }
});

// GET /api/auth/me - who am I
router.get('/me', authenticate, async (req, res, next) => {
  try {
    const r = await db.query('SELECT * FROM users WHERE id = $1', [req.user.id]);
    if (!r.rows[0]) return res.status(404).json({ error: 'User not found' });
    return res.json({ user: publicUser(r.rows[0]) });
  } catch (err) { return next(err); }
});

module.exports = router;
