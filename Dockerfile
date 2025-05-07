ARG ELIXIR_VERSION=1.17.1
ARG OTP_VERSION=26.2.5
ARG DEBIAN_VERSION=bullseye-20240612-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

# Install build dependencies
RUN apt-get update -y && apt-get install -y \
    build-essential git make libssl-dev libc6-dev libsqlite3-dev nodejs npm libxml2-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app
ENV MIX_ENV=prod
# Copy and fetch Elixir deps
COPY mix.exs mix.lock ./
RUN mix local.hex --force && mix local.rebar --force
RUN mix deps.get
RUN mkdir -p config

# Copy configs early
COPY config/ config/
RUN mix deps.compile

# Copy source
COPY priv priv
COPY lib lib
COPY assets assets/

# Install NPM deps (inside assets)
WORKDIR /app/assets
RUN npm install d3 && npm install --legacy-peer-deps

WORKDIR /app
# Build assets
RUN mix assets.deploy

# Move back to app dir
WORKDIR /app

# Compile Elixir app
RUN mix compile

# Copy runtime config before release
COPY config/runtime.exs config/
COPY rel rel
RUN mix release

# Build MKRAND
RUN git clone https://github.com/taguniversalmachine/MKRAND-1.git /app/lib/c/MKRAND-1
WORKDIR /app/lib/c/MKRAND-1
RUN make -f src/Makefile.simple

# Build RC
RUN git clone https://github.com/taguniversal/rc.git /app/lib/c/rc
WORKDIR /app/lib/c/rc
RUN make -f Makefile

# =========================== Runner Stage ===========================

FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates libsqlite3-0 libxml2 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Fly CLI (optional for your infra)
RUN curl -L https://fly.io/install.sh | sh

# Set locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENV RCNODE_PATH="/usr/local/bin/rcnode"

WORKDIR /app
RUN mkdir -p /app /app/state /app/inv
RUN chown -R nobody:root /app

ENV MIX_ENV="prod"

# Only copy needed artifacts
COPY --from=builder --chown=nobody:root /app/_build/prod/rel/digitalblockchain ./ 
COPY --from=builder --chown=nobody:root /app/lib/c/MKRAND-1/mkrand /usr/local/bin/
COPY --from=builder --chown=nobody:root /app/lib/c/rc/build/rcnode /usr/local/bin/
COPY --from=builder --chown=nobody:root /app/lib/c/rc/inv/ /app/inv/

USER nobody

CMD ["/app/bin/server"]
