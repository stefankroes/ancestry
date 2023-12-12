%w[5.2.8 6.0.6 6.1.7 7.0.8 7.1.2].each do |ar_version|
  appraise "gemfile-#{ar_version.split('.').first(2).join}" do
    gem 'activerecord', "~> #{ar_version}"
  end
end
