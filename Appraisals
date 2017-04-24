%w(mysql pg sqlite3).each do |db_type|
  %w(3.2.22.5 4.0.13 4.1.16 4.2.7.1 5.0.0.1 5.1.0.rc1).each do |ar_version|
    # rails 5.0 only supports 'mysql2' driver
    # rails 4.2 supports both
    db_gem = db_type
    db_gem = "mysql2" if ar_version >= "5.0" && db_type == "mysql"
    appraise "#{db_gem}-ar-#{ar_version.split('.').first(2).join}" do
      gem "activerecord", ar_version
      gem db_gem if db_type == "mysql"
      gem "pg", "0.18.4" if db_type == "pg"
      # Skip sqlite3 since it's part of the base Gemfile.
    end
  end
end
