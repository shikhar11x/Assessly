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
- Phase 2f-3: exam screen (server-based countdown, question palette, mark for review,
  autosave, auto-submit, tab-switch warning, score screen); light/dark theme with
  persistent toggle; dashboard redesign. Coding editor follows in 2f-4.
- Phase 2f-4: code editor with Run (sample) and Submit (all cases) verdicts, code autosave,
  detailed result page reachable from the exam and the dashboard.
- Phase 2f-5: teacher dashboard - assessment list and creation, question bank (MCQ and
  coding with test cases), CSV student import, attendance-based assignment, publish and
  unpublish, submissions, analytics. Phase 2 (application MVP) complete.
- Phase 3: containerization - multi-stage non-root backend image, Flutter web + unprivileged
  nginx frontend image (same-origin /api proxy), one-shot migration service, full Docker Compose
  stack with healthchecks, ordered startup, read-only filesystems, dropped capabilities and
  resource limits.
- Phase 4: Jenkins controller (config-as-code, Docker CLI, Node 22) and Jenkinsfile: unit and integration tests with JUnit reports, Flutter analyze/test, image build tagged with commit SHA, container smoke test, optional Docker Hub push.

- Phase 4: Jenkins controller (config-as-code, Docker CLI, Node 22) and Jenkinsfile: unit and integration tests with JUnit reports, Flutter analyze/test, image build tagged with commit SHA, container smoke test, optional Docker Hub push, GitHub webhook trigger via Cloudflare quick tunnel.

- Phase 2g-1: change password, student performance history, teacher attendance edit, unassign, per-attempt detail and CSV results export (backend).

- Phase 2g-2a: design system tokens (warm light / GitHub dark), BLoC introduced with ThemeCubit.

- Phase 2g-2b: reusable widgets, responsive sidebar shell for faculty and student, login and exam on design tokens.

- Phase 2g-3 (backend): admin role, departments, courses, batches, enrollment, bulk CSV batch import, faculty creation, platform stats.

- Phase 2g-3b: admin UI (overview, departments, courses, batches with CSV import, faculty) and admin routing.

- Phase 2g-4a: migrations for new question types, negative marking and instructions; grading logic with unit tests.

- Phase 2g-4b: teacher can create all question types and negative marking/instructions; student answers and final grading for msq, true/false, fill-blank, numeric; short/long left for manual grading.

- Phase 2g-4b and 2g-3c: all question types graded with negative marking; admin manages all assessments, enrolls students and assigns batches.


