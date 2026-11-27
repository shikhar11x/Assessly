# Backend image: multi-stage, production dependencies only, runs as the non-root "node" user.
# Build context is the repository root:  docker build -f docker/backend.Dockerfile .
FROM node:22-alpine AS deps
WORKDIR /srv/backend
COPY application/backend/package.json application/backend/package-lock.json ./
RUN npm ci --omit=dev

FROM node:22-alpine
ENV NODE_ENV=production
WORKDIR /srv/backend
COPY --from=deps /srv/backend/node_modules ./node_modules
COPY application/backend/package.json ./
COPY application/backend/src ./src
# migrate.js looks for ../../database/migrations relative to src, i.e. /srv/database/migrations
COPY application/database/migrations /srv/database/migrations
USER node
EXPOSE 3000
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=5 \
  CMD node -e "fetch('http://127.0.0.1:3000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "src/server.js"]
