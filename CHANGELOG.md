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
  counter, MCQ auto-grading, result breakdown. Coding grading follows in 2e.
- Phase 2d: teacher APIs - assessment CRUD with publish/unpublish, question bank
  (MCQ and coding with test cases), CSV student import with per-row error report,
  assignment (explicit or all attendance-eligible), submissions list, result
  analytics. Teachers are isolated from each other; questions lock once attempts exist.
