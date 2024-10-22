# on a mac using:
# bundle config --global build.mysql2 "--with-mysql-dir=$(brew --prefix mysql)"

%w[5.2.8 6.0.6 6.1.7 7.0.8 7.1.3 7.2.1].each do |ar_version|
  appraise "gemfile-#{ar_version.split('.').first(2).join}" do
    gem 'activerecord', "~> #{ar_version}"
    # active record 5.2 uses ruby 2.6
    # active record 6.x uses ruby 2.7 (sometimes 3.0)
    # so we are targeting the ruby version indirectly through active record
    if ar_version < "7.0"
      gem "sqlite3", "~> 1.6.9"
    else
      # sqlite3 v 2.0 is causing trouble with rails
      gem "sqlite3", "< 2.0"
    end
  end
end
