%w(3.0.20 3.1.12 3.2.22 4.0.13 4.1.14 4.2.5).each do |ar_version|
  %w(sqlite3 pg mysql).each do |db_type|
    appraise "#{db_type}-ar-#{ar_version.split('.').first(2).join}" do
      gem "activerecord", ar_version
      #gem db_type
    end
  end
end
