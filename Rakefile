# frozen_string_literal: true

require 'bundler/setup'
require 'bundler/gem_tasks'
require 'rake/testtask'
require 'yard/rake/yardoc_task'

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the ancestry plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc 'Generate documentation for the ancestry plugin.'
YARD::Rake::YardocTask.new do |t|
  t.files   = ['README.rdoc', 'lib/**/*.rb']
  t.options = ['--any', '--extra', '--opts'] # optional
end

task :doc => :yard
