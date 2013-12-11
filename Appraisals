%w(3.0.20 3.1.12 3.2.14 4.0.1).each do |ar_versions|
  %w(sqlite3 pg mysql).each do |db_type|
    appraise "#{db_type}-ar-#{ar_versions}" do
      gem 'activerecord', ar_versions
      gem db_type
    end
  end
end
