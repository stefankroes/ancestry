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

def compose_command
  @compose_command ||= begin
    if container_engine == "podman" && system("podman compose version > /dev/null 2>&1")
      "podman compose"
    elsif system("docker compose version > /dev/null 2>&1")
      "docker compose"
    elsif system("podman-compose version > /dev/null 2>&1")
      "podman-compose"
    else
      abort("Install `podman compose`, `docker compose`, or `podman-compose` to run compose tasks.")
    end
  end
end

def compose_file_for(target)
  ENV.fetch("COMPOSE_FILE", File.join("docker", "compose.#{target}.yml"))
end

def compose_exec(target, command, service: "app", tty: false)
  tty_flag = tty ? "" : "-T "
  escaped_command = command.gsub("'", %q('"'"'))
  sh "#{compose_command} -f #{compose_file_for(target)} exec #{tty_flag}#{service} bash -lc '#{escaped_command}'"
end

def compose_build(target)
  sh "#{compose_command} -f #{compose_file_for(target)} build app"
end

def compose_up(target, *services)
  service_list = services.join(" ")
  sh "#{compose_command} -f #{compose_file_for(target)} up -d #{service_list}".strip
end

def compose_project_teardown(target)
  sh "#{compose_command} -f #{compose_file_for(target)} down --remove-orphans --volumes"
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

namespace :container do
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

namespace :compose do
  desc "Build the SQLite compose app image"
  task :build_sqlite do
    compose_build("sqlite")
  end

  desc "Build the PostgreSQL compose app image"
  task :build_pg do
    compose_build("pg")
  end

  desc "Build the MySQL compose app image"
  task :build_mysql do
    compose_build("mysql")
  end

  desc "Start the PostgreSQL compose project"
  task :up_pg => :build_pg do
    compose_up("pg", "postgres", "app")
  end

  desc "Start the MySQL compose project"
  task :up_mysql => :build_mysql do
    compose_up("mysql", "mysql", "app")
  end

  desc "Stop the SQLite compose project"
  task :down_sqlite do
    compose_project_teardown("sqlite")
  end

  desc "Stop the PostgreSQL compose project"
  task :down_pg do
    compose_project_teardown("pg")
  end

  desc "Stop the MySQL compose project"
  task :down_mysql do
    compose_project_teardown("mysql")
  end

  desc "Open a shell in the SQLite compose app container"
  task :shell_sqlite => :build_sqlite do
    compose_up("sqlite", "app")
    compose_exec("sqlite", "bash", tty: true)
  end

  desc "Open a shell in the PostgreSQL compose app container"
  task :shell_pg => :up_pg do
    compose_exec("pg", "bash", tty: true)
  end

  desc "Open a shell in the MySQL compose app container"
  task :shell_mysql => :up_mysql do
    compose_exec("mysql", "bash", tty: true)
  end

  desc "Run the SQLite test suite in the compose app container"
  task :test_sqlite => :build_sqlite do
    begin
      compose_up("sqlite", "app")
      compose_exec("sqlite", "bundle exec rake test")
    ensure
      compose_project_teardown("sqlite")
    end
  end

  desc "Run the PostgreSQL test suite in the compose app container"
  task :test_pg => :up_pg do
    begin
      compose_exec("pg", "DB=pg bundle exec rake test")
    ensure
      compose_project_teardown("pg")
    end
  end

  desc "Run the MySQL test suite in the compose app container"
  task :test_mysql => :up_mysql do
    begin
      compose_exec("mysql", "DB=mysql bundle exec rake test")
    ensure
      compose_project_teardown("mysql")
    end
  end

  desc "Run SQLite, PostgreSQL, and MySQL tests via compose"
  task :test do
    Rake::Task["compose:test_sqlite"].invoke
    Rake::Task["compose:test_pg"].invoke
    Rake::Task["compose:test_mysql"].invoke
  end
end

namespace :test do
  desc "Build the compose app image, start databases, and run SQLite/PostgreSQL/MySQL tests"
  task :compose => "compose:test"
end

namespace :docker do
  desc "Alias for container:build"
  task :build => "container:build"

  desc "Alias for container:test"
  task :test => "container:test"

  desc "Alias for container:shell"
  task :shell => "container:shell"
end
