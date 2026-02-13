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
  && git init /app \
  && git -C /app config user.email "docker@local" \
  && git -C /app config user.name "Docker" \
  && git -C /app config core.logAllRefUpdates true \
  && git -C /app commit --allow-empty -m "container build" \
  && chown -R node:node /app/.git

USER node

EXPOSE 9000
CMD ["node","src/cobalt"]


EXPOSE 9000
CMD [ "node", "src/cobalt" ]
