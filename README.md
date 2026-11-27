# Assessly - Cloud-Native Online Assessment Platform

End-to-end DevOps capstone: Flutter Web + Node.js/Express + PostgreSQL,
delivered through Jenkins CI/CD, Docker, Kubernetes (Minikube), Helm,
Terraform, Ansible, Argo CD/Rollouts, Prometheus, Grafana, Loki and Alertmanager.

> Status: **Phase 1 - Project Foundation**. Sections are filled in as each phase is completed and tested.

## Prerequisites
Windows 11, WSL2 Ubuntu, Docker Desktop, Node.js 20+, Flutter SDK (stable), Git.

## Local execution (current)

### Backend (PowerShell)
    cd application/backend
    npm install
    Copy-Item .env.example .env
    npm test
    npm start
    # GET http://localhost:3000/health

### Frontend
    cd application/frontend/assessly_flutter
    flutter pub get
    flutter analyze

## Repository layout
application, docker, jenkins, security, infrastructure, kubernetes,
gitops, monitoring, logging, scripts, sample-data, docs.

## Docker execution (Phase 3)

Requires Docker Desktop. From the repository root (PowerShell):

    Copy-Item docker/.env.example docker/.env   # then edit docker/.env: set real passwords/secrets
    docker compose -f docker/docker-compose.yml --env-file docker/.env up -d --build
    docker compose -f docker/docker-compose.yml --env-file docker/.env ps -a

Open http://localhost:8090 (frontend; nginx proxies /api to the backend).
Backend health: http://127.0.0.1:3002/health. Stop with `down` (add `-v` only to delete the database volume).
Optional demo data: `docker compose -f docker/docker-compose.yml --env-file docker/.env run --rm migrate node src/seed.js`

All app containers run as non-root with all Linux capabilities dropped, read-only filesystems and memory limits.
Images: `docker/backend.Dockerfile` (multi-stage Node), `docker/frontend.Dockerfile` (Flutter build + unprivileged nginx).
