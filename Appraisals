%w(5.0.7 5.1.7 5.2.3 6.0.0 6.1.0).each do |ar_version|
  if RUBY_VERSION < '3.0.0' || ar_version >= '6.1.0'
    appraise "gemfile-#{ar_version.split('.').first(2).join}" do
      gem "activerecord", ar_version
      gem "pg"
      gem "mysql2"
      if ar_version < "5.2"
        gem "sqlite3", "~> 1.3.13"
      else
        gem "sqlite3"
      end
    end
  end
end
