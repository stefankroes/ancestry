# frozen_string_literal: true

# on a mac using:
# bundle config --global build.mysql2 "--with-mysql-dir=$(brew --prefix mysql)"

%w[6.0.6 6.1.7 7.0.8 7.1.3 7.2.1 8.0.0].each do |ar_version|
  appraise "gemfile-#{ar_version.split('.').first(2).join}" do
    gem 'activerecord', "~> #{ar_version}"
    # so we are targeting the ruby version indirectly through active record
    if ar_version < "7.0"
      gem "sqlite3", "~> 1.6.9"
    elsif ar_version < "8.0"
      # sqlite3 v 2.0 is causing trouble with rails
      gem "sqlite3", "< 2.0"
    else
      # Rails 8.0 requires sqlite3 >= 2.1
      gem "sqlite3", ">= 2.1"
    end
  end
end
