# ==========================================
# Base Stage - Foundation for all stages
# ==========================================
FROM elixir:1.18-slim AS base

# Install essential runtime dependencies
RUN apt-get update -y && \
    apt-get install -y \
      libstdc++6 \
      openssl \
      libncurses5 \
      locales \
      ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

WORKDIR /app

# ==========================================
# Deps Stage - Install build dependencies
# ==========================================
FROM base AS deps

# Install build dependencies
RUN apt-get update -y && \
    apt-get install -y \
      build-essential \
      git \
      postgresql-client \
      curl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Node.js 20.x for asset compilation
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Fix for cross-platform builds with QEMU (Erlang JIT issue)
ENV ERL_FLAGS="+JPperf true"

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# ==========================================
# Dev Stage - Development environment
# ==========================================
FROM deps AS dev

# Install development tools
RUN apt-get update -y && \
    apt-get install -y inotify-tools && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# This stage is used by docker-compose with volumes
# Dependencies are installed at runtime via compose volumes
CMD ["sh", "-c", "mix deps.get && mix phx.server"]

# ==========================================
# Builder Stage - Compile application
# ==========================================
FROM deps AS builder

# Set build environment
ENV MIX_ENV=prod

# Copy mix files
COPY mix.exs mix.lock ./

# Install and compile dependencies
RUN mix deps.get --only prod && \
    mix deps.compile

# Copy application source
COPY config ./config
COPY lib ./lib
COPY priv ./priv
COPY assets ./assets

# Compile assets
RUN mix assets.setup && \
    mix assets.deploy

# Compile application
RUN mix compile

# Create release
RUN mix release

# ==========================================
# Runner Stage - Minimal production image
# ==========================================
FROM base AS runner

# Install runtime dependencies
RUN apt-get update -y && \
    apt-get install -y postgresql-client && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r curupira && useradd -r -g curupira curupira

# Create app directory
RUN mkdir -p /app
WORKDIR /app

# Copy release from builder
COPY --from=builder --chown=curupira:curupira /app/_build/prod/rel/curupira ./

# Switch to non-root user
USER curupira

# Set environment
ENV HOME=/app \
    MIX_ENV=prod \
    PHX_SERVER=true

# Expose port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD ["sh", "-c", "curl -f http://localhost:4000/ || exit 1"]

# Start application
CMD ["sh", "-c", "/app/bin/curupira eval 'Curupira.Release.migrate()' && /app/bin/curupira start"]
