require 'rake'
require 'rake/testtask'
require 'rdoc/task'

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the ancestry plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc 'Test the ancestry plugin with multiple databases and activerecord versions.'
task :test_all do |t|
  commands = []
  %w(3.0.0 3.1.0 3.2.0).each do |activerecord_version|
    %w(sqlite3 postgresql mysql).each do |database_adapter|
      commands << "rake test ar=#{activerecord_version} db=#{database_adapter}"
    end
  end
  
  exec commands.join(' && ')
end

desc 'Generate documentation for the ancestry plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title    = 'Ancestry'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
