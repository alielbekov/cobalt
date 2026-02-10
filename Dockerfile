FROM base AS api
WORKDIR /app

ARG GIT_SHA=unknown
ENV GIT_SHA=$GIT_SHA

COPY --from=build --chown=node:node /prod/api /app

USER node
EXPOSE 9000
CMD [ "node", "src/cobalt" ]