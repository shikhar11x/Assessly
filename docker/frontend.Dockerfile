# Frontend image: Flutter web build, then served by unprivileged nginx (non-root, port 8080).
# Build context is the repository root:  docker build -f docker/frontend.Dockerfile .
# Flutter is cloned at the exact tag used in development, so builds are reproducible.
FROM debian:bookworm-slim AS build
ARG FLUTTER_VERSION=3.47.8
RUN apt-get update \
    && apt-get install -y --no-install-recommends git curl unzip xz-utils ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"
RUN git config --global --add safe.directory /opt/flutter \
    && flutter config --no-analytics --enable-web \
    && flutter precache --web \
    && flutter --version

WORKDIR /app
COPY application/frontend/assessly_flutter/pubspec.yaml application/frontend/assessly_flutter/pubspec.lock ./
RUN flutter pub get
COPY application/frontend/assessly_flutter/ ./
# "same-origin" makes the app call /api on whichever host served it (nginx proxies it to the backend)
ARG API_BASE_URL=same-origin
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}

FROM nginxinc/nginx-unprivileged:1.27-alpine
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=5 \
  CMD wget -q --spider http://127.0.0.1:8080/healthz || exit 1
