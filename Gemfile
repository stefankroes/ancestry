# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem "activerecord", "~> 7.2"
gem "sqlite3", "~> 1.6.9"

if ENV["BUNDLE_INSTALL_MYSQL"] == "1"
  gem "mysql2"
end

if ENV["BUNDLE_INSTALL_POSTGRES"] == "1"
  gem "pg"
end

# Container tooling is development-only; docker/podman files are explicitly excluded from packages.
