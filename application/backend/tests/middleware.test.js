'use strict';

const jwt = require('jsonwebtoken');
const { authenticate, requireRole } = require('../src/middleware_auth');

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

describe('authenticate middleware', () => {
  it('rejects a request without Authorization header', () => {
    const res = mockRes();
    const next = jest.fn();
    authenticate({ headers: {} }, res, next);
    expect(res.status).toHaveBeenCalledWith(401);
    expect(next).not.toHaveBeenCalled();
  });

  it('rejects a bad token', () => {
    const res = mockRes();
    const next = jest.fn();
    authenticate({ headers: { authorization: 'Bearer not-a-token' } }, res, next);
    expect(res.status).toHaveBeenCalledWith(401);
  });

  it('accepts a valid token and sets req.user', () => {
    const token = jwt.sign({ role: 'student' }, process.env.JWT_SECRET, { subject: 'u1' });
    const req = { headers: { authorization: `Bearer ${token}` } };
    const next = jest.fn();
    authenticate(req, mockRes(), next);
    expect(next).toHaveBeenCalled();
    expect(req.user).toEqual({ id: 'u1', role: 'student' });
  });
});

describe('requireRole middleware', () => {
  it('blocks a student from a teacher-only route', () => {
    const res = mockRes();
    const next = jest.fn();
    requireRole('teacher')({ user: { role: 'student' } }, res, next);
    expect(res.status).toHaveBeenCalledWith(403);
    expect(next).not.toHaveBeenCalled();
  });

  it('allows a teacher', () => {
    const next = jest.fn();
    requireRole('teacher')({ user: { role: 'teacher' } }, mockRes(), next);
    expect(next).toHaveBeenCalled();
  });
});
