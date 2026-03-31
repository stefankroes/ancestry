# syntax=docker/dockerfile:1

FROM docker.io/library/ruby:3.3-slim

ARG BUNDLE_INSTALL_SQLITE3=0
ARG BUNDLE_INSTALL_MYSQL=0
ARG BUNDLE_INSTALL_POSTGRES=0

ENV APP_ROOT=/app \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_INSTALL_SQLITE3=${BUNDLE_INSTALL_SQLITE3} \
    BUNDLE_INSTALL_MYSQL=${BUNDLE_INSTALL_MYSQL} \
    BUNDLE_INSTALL_POSTGRES=${BUNDLE_INSTALL_POSTGRES}

WORKDIR $APP_ROOT

RUN apt-get update -y \
  && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    libpq-dev \
    libsqlite3-dev \
    default-libmysqlclient-dev \
    pkg-config \
  && rm -rf /var/lib/apt/lists/*

# Bundler needs the version file where the gemspec expects it.
COPY lib/ancestry/version.rb ./lib/ancestry/version.rb
COPY Gemfile* *.gemspec Appraisals ./

RUN bundle config set --local path "$BUNDLE_PATH" \
  && bundle install --jobs 4 --retry 3

COPY . .

CMD ["bundle", "exec", "rake", "test"]
