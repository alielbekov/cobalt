FROM node:24-alpine AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

FROM base AS build
WORKDIR /app
COPY . /app

RUN corepack enable
RUN apk add --no-cache python3 alpine-sdk

RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm install --prod --frozen-lockfile

RUN pnpm deploy --filter=@imput/cobalt-api --prod /prod/api

FROM base AS api
WORKDIR /app
ENV NODE_ENV=production

COPY --from=build --chown=node:node /prod/api /app

# Create a minimal git repo so @imput/version-info won't crash
USER root
RUN apk add --no-cache git \
  && git init . \
  && git config user.email "docker@local" \
  && git config user.name "Docker" \
  && git remote add origin https://github.com/alielbekov/cobalt.git \
  && git config core.logAllRefUpdates true \
  && git commit --allow-empty -m "container build" \
  && chown -R node:node .git

# Writable dir for runtime files (mount this as a volume in Coolify if you want persistence)
RUN mkdir -p /data && chown -R node:node /data

# Entry-point: if COOKIES_JSON is set, write it to COOKIE_PATH (default /data/cookies.json)
# Use printf (not echo) to avoid weird escaping/newline issues.
RUN printf '%s\n' \
'#!/bin/sh' \
'set -eu' \
': "${COOKIE_PATH:=/data/cookies.json}"' \
'' \
'if [ -n "${COOKIES_JSON:-}" ]; then' \
'  mkdir -p "$(dirname "$COOKIE_PATH")"' \
'  printf "%s" "$COOKIES_JSON" > "$COOKIE_PATH"' \
'fi' \
'' \
'exec "$@"' \
> /app/entrypoint.sh \
 && chmod +x /app/entrypoint.sh \
 && chown node:node /app/entrypoint.sh

USER node

# IMPORTANT: make COOKIE_PATH absolute so reads/writes match no matter the working dir
ENV COOKIE_PATH=/data/cookies.json

EXPOSE 9000
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["node", "src/cobalt"]
