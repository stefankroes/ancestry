%w[5.2.6 6.0.3 6.1.3 7.0.0].each do |ar_version|
  appraise "gemfile-#{ar_version.split('.').first(2).join}" do
    gem 'activerecord', "~> #{ar_version}"
  end
end
