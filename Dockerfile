# syntax=docker/dockerfile:1
# check=error=true

# Portable production image — runs Puma directly on any platform (ECS, Kubernetes,
# Fly.io, Render, Cloud Run, plain Docker). Build and run by hand:
# docker build --build-arg GIT_SHA=$(git rev-parse HEAD) -t rails_api_starter_template .
# docker run -d -p 3000:3000 -e RAILS_MASTER_KEY=<value from config/master.key> --name rails_api_starter_template rails_api_starter_template

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=4.0.2
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips postgresql-client && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment variables and enable jemalloc for reduced memory usage and latency.
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libvips libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY vendor/* ./vendor/
COPY Gemfile Gemfile.lock ./

RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    # -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
    bundle exec bootsnap precompile -j 1 --gemfile

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times.
# -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
RUN bundle exec bootsnap precompile -j 1 app/ lib/




# Final stage for app image
FROM base

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

# Copy built artifacts: gems, application. --chown makes the whole app tree (including
# /rails/tmp, where the Section 10 shutdown sentinel is written at runtime) owned by
# the non-root rails user.
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

# Commit SHA baked at build time — populates the `commit` field in /health (Section 4).
ARG GIT_SHA=unknown
ENV GIT_SHA=${GIT_SHA}

# Entrypoint prepares the database (migrations are opt-in via RUN_DB_PREPARE).
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Puma reads PORT (config/puma.rb), so any platform can override it.
ENV PORT=3000
EXPOSE 3000

# Container-level liveness check hitting the Rails /up probe.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl -fsS http://localhost:${PORT}/up || exit 1

# Start Puma directly (portable — no Thruster). Overridable at runtime.
CMD ["./bin/rails", "server"]
