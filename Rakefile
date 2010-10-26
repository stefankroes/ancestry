require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rcov/rcovtask'

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the ancestry plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc 'Determine test code coverage for the ancestry plugin.'
Rcov::RcovTask.new(:coverage) do |t|
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb']
  t.verbose = true
  t.output_dir = "test/coverage"
  t.rcov_opts << "-x /gems/,/library/"
end

desc 'Generate documentation for the ancestry plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title    = 'Ancestry'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
