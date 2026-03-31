# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem "activerecord", "~> 7.2"
gem "mysql2" if ENV["BUNDLE_INSTALL_MYSQL"] == "1" || File.basename($PROGRAM_NAME) == "appraisal"
gem "trilogy"
gem "pg"
gem "sqlite3", "~> 1.6.9"
