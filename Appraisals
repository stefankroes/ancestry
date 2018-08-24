%w(mysql pg sqlite3).each do |db_type|
  %w(4.2.10 5.0.7 5.1.6 5.2.0).each do |ar_version|
    # rails 5.0 only supports 'mysql2' driver
    # rails 4.2 supports both ( but travis complaining with 4.2 and mysql2)
    db_gem = db_type
    db_gem = "mysql2" if db_type == "mysql" # ar_version >= "5.0" &&
    appraise "#{db_gem}-ar-#{ar_version.split('.').first(2).join}" do
      gem "activerecord", ar_version
      gem db_gem if db_type == "mysql"
      if db_type == "pg"
        if ar_version >= "5.0"
          gem "pg"
        else 
          gem "pg", "0.18.4"
        end
      end
      if db_type == "mysql"
        if ar_version >= "5.0"
          gem "mysql2"
        else 
          gem "mysql2", '~> 0.4.0'
        end
      end
      # Skip sqlite3 since it's part of the base Gemfile.
    end
  end
end
