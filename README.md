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
