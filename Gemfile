# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem "activerecord", "~> 7.2"
gem "trilogy"

if ENV["BUNDLE_INSTALL_PG"] == "1" || File.basename($PROGRAM_NAME) == "appraisal"
  gem "pg"
end

if ENV["BUNDLE_INSTALL_MYSQL"] == "1" || File.basename($PROGRAM_NAME) == "appraisal"
  gem "mysql2"
end

if ENV["BUNDLE_INSTALL_SQLITE3"] == "1" || File.basename($PROGRAM_NAME) == "appraisal"
  gem "sqlite3", "~> 1.6.9"
end
