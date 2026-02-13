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
# Create entrypoint script to handle COOKIES_JSON env var
RUN printf '#!/bin/sh\nif [ -n "$COOKIES_JSON" ]; then\n  echo "$COOKIES_JSON" > /app/cookies.json\n  chown node:node /app/cookies.json\nfi\nexec "$@"\n' > /app/entrypoint.sh && chmod +x /app/entrypoint.sh

USER node

ENV COOKIE_PATH=cookies.json

EXPOSE 9000
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["node", "src/cobalt"]
