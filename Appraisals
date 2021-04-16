%w(6.0.3.6 6.1.3.1).each do |ar_version|
  appraise "gemfile-#{ar_version.split('.').first(2).join}" do
    gem "activerecord", ar_version
    gem "pg"
    gem "mysql2"
    gem "sqlite3"
  end
end
