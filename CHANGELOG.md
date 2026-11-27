# Changelog

## [Unreleased]
### Added
- Phase 1: monorepo structure, .gitignore, Flutter web scaffold,
  Express backend with /health endpoint, Jest/Supertest tests, README.
- Phase 2a: PostgreSQL 16 in Docker Compose (host port 5433), initial schema
  migration, migration runner, idempotent seed data.
- Phase 2b: JWT authentication (register/login/me), role-based authorization,
  unit and integration tests.
- Phase 2c: assessment engine - random 5-of-10 question selection per student,
  server-side timer with grace period, attendance eligibility, duplicate-attempt
  prevention (DB constraint + concurrency test), answer saving, tab-switch
  counter, MCQ auto-grading, result breakdown.
- Phase 2d: teacher APIs - assessment CRUD with publish/unpublish, question bank
  (MCQ and coding with test cases), CSV student import with per-row error report,
  assignment (explicit or all attendance-eligible), submissions list, result
  analytics. Teachers are isolated from each other; questions lock once attempts exist.
- Phase 2e: coding assessment - isolated execution service (own container, unprivileged
  uid, timeout/memory/process/output limits, read-only filesystem, token auth, init
  process as PID 1), Run (sample case) and Submit (all cases, hidden cases masked,
  partial credit), run rate limiting, sandbox attack-test script with recorded
  evidence. Known dev limitation: outbound network is not blocked in local Docker;
  a NetworkPolicy covers this in Phase 6.
- Phase 2f-1: Flutter skeleton - API client, login/register, session restore,
  role-based routing, widget tests.
- Phase 2f-2: student dashboard - assessment list, attendance and eligibility display,
  start (with confirmation) and resume; placeholder exam page; login page redesign;
  backend accepts multiple CORS origins.
