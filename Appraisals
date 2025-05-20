# frozen_string_literal: true

# on a mac using:
# bundle config --global build.mysql2 "--with-mysql-dir=$(brew --prefix mysql)"

%w[7.0.8 7.1.3 7.2.1].each do |ar_version|
  appraise "gemfile-#{ar_version.split('.').first(2).join}" do
    gem 'activerecord', "~> #{ar_version}"
    # so we are targeting the ruby version indirectly through active record

    # sqlite3 v 2.0 is causing trouble with rails
    gem "sqlite3", "< 2.0"
  end
end
