FROM node:24-alpine AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

FROM base AS build
WORKDIR /app

# Install build tools (needed for native deps)
RUN apk add --no-cache python3 alpine-sdk

# Copy source
COPY . .

# Install deps (NOT --prod in build stage)
RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm install --frozen-lockfile

# Produce production deploy output
RUN pnpm deploy --filter=@imput/cobalt-api --prod /prod/api

FROM base AS api
WORKDIR /app
ENV NODE_ENV=production

COPY --from=build --chown=node:node /prod/api /app
RUN echo "unknown" > /app/COMMIT_SHA

USER node
EXPOSE 9000
CMD ["node", "src/cobalt"]
