%w(4.2.10 5.0.7 5.1.7 5.2.3 6.0.0).each do |ar_version|
  appraise "gemfile-#{ar_version.split('.').first(2).join}" do
    gem "activerecord", ar_version
    if ar_version < "5.0"
      gem "pg", "0.18.4"
    else
      gem "pg"
    end
    # rails 5.0 only supports 'mysql2' driver
    # rails 4.2 supports both ( but travis complains with 4.2 and mysql2)
    if ar_version < "4.2"
      gem "mysql"
    elsif ar_version < "5.0"
      gem "mysql2", '~> 0.4.0'
    else
      gem "mysql2"
    end
    if ar_version < "5.2"
      gem "sqlite3", "~> 1.3.13"
    else
      gem "sqlite3"
    end
  end
end
