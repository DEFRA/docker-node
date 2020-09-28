# Set default values for build arguments
ARG DOCKERFILE_VERSION=1.2.0
ARG NODE_VERSION=12.18.3-alpine3.12

FROM node:$NODE_VERSION AS production

ARG NODE_VERSION
ARG DOCKERFILE_VERSION

ENV NODE_ENV production

# Set global npm dependencies to be stored under the node user directory
ENV NPM_CONFIG_PREFIX=/home/node/.npm-global
ENV PATH=$PATH:/home/node/.npm-global/bin

# We need a basic init process to handle signals and reap zombie processes, tini handles that
# Install Internal CA certificate
RUN apk update && apk add --no-cache tini && apk add ca-certificates && rm -rf /var/cache/apk/*
COPY certificates/internal-ca.crt /usr/local/share/ca-certificates/internal-ca.crt
RUN chmod 644 /usr/local/share/ca-certificates/internal-ca.crt && update-ca-certificates

ENTRYPOINT ["/sbin/tini", "--"]

# Never run as root, default to the node user (created by the base Node image)
USER node

# Default workdir should be owned by the default user
WORKDIR /home/node

# Label images to aid searching
LABEL uk.gov.defra.node.node-version=$NODE_VERSION \
      uk.gov.defra.node.version=$DOCKERFILE_VERSION \
      uk.gov.defra.node.repository=defradigital/node

FROM production AS development

ENV NODE_ENV development

LABEL uk.gov.defra.node.repository=defradigital/node-development

# node-gyp is a common requirement for NPM packages. It must be installed as root.
USER root
RUN apk update && \
    apk add --no-cache git && \
    apk add --no-cache --virtual .gyp python2=~2.7 make g++=~9.3
# Pact dependencies are not included in Alpine image for contract testing
RUN apk add --no-cache bash wget \
    && wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub \
    && wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.29-r0/glibc-2.29-r0.apk \
    && apk add glibc-2.29-r0.apk
USER node
