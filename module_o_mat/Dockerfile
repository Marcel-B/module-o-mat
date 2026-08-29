# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the builder image
#     E.g.: docker.io/hexpm/elixir:1.20.3-erlang-29.0.5-debian-trixie-20260803-slim
#   - https://hub.docker.com/_/debian/tags?name=trixie-20260803-slim - for the runner image
#     E.g.: docker.io/debian:trixie-20260803-slim
#
# Find builder and runner images on Docker Hub or on Hex's Build Server (Bob).
# We recommend using Bob's Web UI to find recent tags:
#
#   - https://bob.hex.pm/docker
#
# We suggest using the same Debian version for both the builder and runner images.
#
# We suggest Debian/Ubuntu instead of Alpine to avoid production compatibility issues
# (such as DNS resolution failures, and dynamically linked NIFs/precompiled binaries).
#
# For finding packages in Debian, search on https://packages.debian.org/.
#
# Build context is the Git repository root (see docker-compose.yml / CI).

ARG ELIXIR_VERSION=1.20.3
ARG OTP_VERSION=29.0.5
ARG DEBIAN_VERSION=trixie-20260803-slim

ARG BUILDER_IMAGE="docker.io/hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="docker.io/debian:${DEBIAN_VERSION}"

FROM node:22-bookworm-slim AS vue-ui
WORKDIR /src
COPY dotnet/src/ModuleOMat.Api/ClientApp/package.json dotnet/src/ModuleOMat.Api/ClientApp/package-lock.json ./
RUN npm ci
COPY dotnet/src/ModuleOMat.Api/ClientApp ./
RUN npm run build && mv dist /out

FROM node:22-bookworm-slim AS vue-ui-alt
WORKDIR /src
COPY module_o_mat/ui-alt/package.json module_o_mat/ui-alt/package-lock.json ./
RUN npm ci
COPY module_o_mat/ui-alt ./
RUN npm run build && mv dist /out

FROM ${BUILDER_IMAGE} AS builder

# install build dependencies (sqlite3 headers for exqlite/ecto_sqlite3)
RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential git libsqlite3-dev \
  && rm -rf /var/lib/apt/lists/*

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force \
  && mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY module_o_mat/mix.exs module_o_mat/mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY module_o_mat/config/config.exs module_o_mat/config/${MIX_ENV}.exs config/
RUN mix deps.compile

RUN mix assets.setup

COPY module_o_mat/priv priv

COPY --from=vue-ui /out priv/vue/ui
COPY --from=vue-ui-alt /out priv/vue/ui-alt

COPY module_o_mat/lib lib

# Compile the release
RUN mix compile

COPY module_o_mat/assets assets

# compile assets
RUN mix assets.deploy

# Changes to config/runtime.exs don't require recompiling the code
COPY module_o_mat/config/runtime.exs config/

COPY module_o_mat/rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE} AS final

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    libstdc++6 \
    openssl \
    libncurses6 \
    locales \
    ca-certificates \
    libsqlite3-0 \
  && rm -rf /var/lib/apt/lists/*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
  && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# Persistent SQLite DB and PDF uploads (mount a volume here)
RUN mkdir -p /data/uploads/manuals \
  && chown -R nobody:nogroup /data

# set runner ENV
ENV MIX_ENV="prod" \
  DATABASE_PATH="/data/module_o_mat.db" \
  MANUAL_UPLOADS_DIR="/data/uploads/manuals"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/module_o_mat ./

# Entrypoint starts as root to chown the mounted /data volume, then drops to nobody.
VOLUME ["/data"]
EXPOSE 4000

# If using an environment that doesn't automatically reap zombie processes, it is
# advised to add an init process such as tini via `apt-get install`
# above and adding an entrypoint. See https://github.com/krallin/tini for details
# ENTRYPOINT ["/tini", "--"]

ENTRYPOINT ["/app/bin/docker-entrypoint"]
