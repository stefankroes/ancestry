# frozen_string_literal: true

docker_task_requested = ARGV.any? { |arg| arg.start_with?("docker:") }

unless docker_task_requested
  require 'bundler/setup'
  require 'bundler/gem_tasks'
  require 'rake/testtask'
  # require 'yard/rake/yardoc_task'
end

def container_engine
  @container_engine ||= begin
    choice = ENV["CONTAINER_ENGINE"]
    choice = %w[podman docker].find { |cmd| system("command -v #{cmd} > /dev/null") } if choice.to_s.empty?
    choice || abort("Install podman or docker (or set CONTAINER_ENGINE) to run container tasks.")
  end
end

def container_image
  ENV.fetch("CONTAINER_IMAGE", "ancestry-dev:latest")
end

def container_mount
  suffix = container_engine == "podman" ? ":Z" : ""
  "#{Dir.pwd}:/app#{suffix}"
end

unless docker_task_requested
  desc 'Default: run unit tests.'
  task :default => :test

  desc 'Test the ancestry plugin.'
  Rake::TestTask.new(:test) do |t|
    t.libs << 'test'
    t.pattern = 'test/**/*_test.rb'
    t.verbose = true
  end

  # desc 'Generate documentation for the ancestry plugin.'
  # YARD::Rake::YardocTask.new do |t|
  #   t.files   = ['README.rdoc', 'lib/**/*.rb']
  #   t.options = ['--any', '--extra', '--opts'] # optional
  # end

  namespace :db do
    desc "Create the database"
    task :create do
      require_relative "test/environment"
      AncestryTestDatabase.create
    rescue ActiveRecord::DatabaseAlreadyExists => e
      puts e.message
    end

    desc "Drop the database"
    task :drop do
      require_relative "test/environment"
      AncestryTestDatabase.drop
      # NOTE: this silently fails if the database does not exist
    end
  end

  desc "Show uncovered lines from coverage results"
  task :coverage do
    require 'json'

    resultset = File.join(__dir__, "coverage", ".resultset.json")
    unless File.exist?(resultset)
      abort "No coverage data found. Run: COVERAGE=1 rake test"
    end

    data = JSON.parse(File.read(resultset))

    # Merge all runs
    merged = {}
    data.each do |_name, run|
      run["coverage"].each do |file, info|
        next unless file.include?("lib/ancestry")
        short = file.sub(/.*lib\/ancestry\//, "")
        lines = info["lines"]
        if merged[short]
          lines.each_with_index { |v, i| merged[short][i] = [merged[short][i].to_i, v.to_i].max if v }
        else
          merged[short] = lines.dup
        end
      end
    end

    puts "Coverage runs: #{data.keys.join(', ')}"
    puts

    total_lines = 0
    total_covered = 0

    merged.sort.each do |file, lines|
      uncovered = []
      coverable = 0
      lines.each_with_index do |hits, i|
        next if hits.nil? # non-executable line
        coverable += 1
        uncovered << i + 1 if hits == 0
      end
      total_lines += coverable
      total_covered += coverable - uncovered.size
      next if uncovered.empty?
      puts "#{file} (#{uncovered.size} uncovered):"
      puts "  Lines: #{uncovered.join(', ')}"
    end

    pct = total_lines > 0 ? (100.0 * total_covered / total_lines).round(1) : 0
    puts
    puts "Total: #{total_covered}/#{total_lines} (#{pct}%)"
  end

  # task :doc => :yard
end

namespace :docker do
  desc "Build the development image (prefers podman, falls back to docker)"
  task :build do
    sh "#{container_engine} build -t #{container_image} ."
  end

  desc "Run the test suite inside the container"
  task :test => :build do
    sh "#{container_engine} run --rm -it -v #{container_mount} -w /app #{container_image} bundle exec rake test"
  end

  desc "Open a shell inside the container with the repo mounted"
  task :shell => :build do
    sh "#{container_engine} run --rm -it -v #{container_mount} -w /app #{container_image} bash"
  end
end
