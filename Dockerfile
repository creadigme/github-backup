ARG NODE_ALPINE_VERSION=18-alpine3.16
FROM node:${NODE_ALPINE_VERSION} AS build
ENV NODE_ENV=production

WORKDIR /data

COPY /build/ /data/build/

FROM node:${NODE_ALPINE_VERSION}
LABEL org.opencontainers.image.source https://github.com/creadigme/github-backup
ENV NODE_ENV=production

WORKDIR /data

RUN apk fix && \
    apk --no-cache --update add git git-lfs gpg less openssh patch && \
    git lfs install

COPY --from=build /data /data

ENTRYPOINT ["node", "/data/build/cli.js"]
