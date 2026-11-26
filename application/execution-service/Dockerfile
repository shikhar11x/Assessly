# Execution service image.
# The server starts as root ONLY so it can drop each student run to an unprivileged uid.
# docker-compose removes every capability except SETUID/SETGID, so root has no extra power.
FROM node:22-alpine
RUN apk add --no-cache python3
WORKDIR /app
COPY package.json ./
COPY src ./src
ENV NODE_ENV=production PORT=4000
EXPOSE 4000
CMD ["node", "src/server.js"]
