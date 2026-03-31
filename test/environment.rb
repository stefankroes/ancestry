# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'
require 'erb'

if ENV["COVERAGE"]
  require 'simplecov'
  require 'simplecov-json'
  SimpleCov.start do
    add_filter '/test/'
    add_filter '/vendor/'
    command_name [
      ENV.fetch("FORMAT", "materialized_path"),
      ENV.fetch("UPDATE_STRATEGY", "ruby"),
      ENV.fetch("DB", "sqlite3"),
    ].join("-")
    formatter SimpleCov::Formatter::MultiFormatter.new([
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::JSONFormatter,
    ])
  end
end

require 'active_support'
require 'active_support/test_case'
require 'active_record'
require 'logger'

# Make absolutely sure we are testing local ancestry
require File.expand_path('../../lib/ancestry', __FILE__)

class AncestryTestDatabase
  def self.setup
    # Silence I18n and Activerecord logging
    I18n.enforce_available_locales = false if I18n.respond_to? :enforce_available_locales=
    ActiveRecord::Base.logger = Logger.new($stderr)
    ActiveRecord::Base.logger.level = Logger::Severity::UNKNOWN

    begin
      connect
      Ancestry.default_update_strategy = ENV["UPDATE_STRATEGY"] == "sql" ? :sql : :ruby
      Ancestry.default_ancestry_format = ENV["FORMAT"].to_sym if ENV["FORMAT"].present?

      if postgres?
        ActiveRecord::Base.connection.execute("CREATE EXTENSION IF NOT EXISTS ltree")
      end

      if array? && !postgres?
        raise "Array format requires PostgreSQL"
      end

      puts "testing #{db_type} #{Ancestry.default_update_strategy == :sql ? "(sql) " : ""}(with #{column_type} #{ancestry_column})"
      puts "column format: #{Ancestry.default_ancestry_format} options: #{column_options.inspect}"
    rescue StandardError => e
      if ENV["CI"]
        raise
      else
        puts "\nSkipping tests for '#{db_type}'"
        puts "  #{e}\n\n"
        exit 0
      end
    end
  end

  def self.column_type
    @column_type ||= if ltree?
      "ltree"
    elsif array?
      "integer_array"
    else
      ENV["ANCESTRY_COLUMN_TYPE"].presence || "string"
    end
  end

  def self.ancestry_column
    @ancestry_column ||= ENV["ANCESTRY_COLUMN"].presence || "ancestry"
  end

  def self.ancestry_root
    format_module = Ancestry::HasAncestry.ancestry_format_module(nil)
    format_module.root
  end

  def self.ancestry_collation
    return @ancestry_collation if defined?(@ancestry_collation)

    env = ENV["ANCESTRY_LOCALE"].presence
    @ancestry_collation =
      if env
        env
      elsif postgres?
        "C"
      elsif db_type =~ /mysql/i
        "utf8mb4_bin"
      else
        "binary"
      end
  end

  # @param force_allow_nil [Boolean] true if we want to allow nulls
  #                        used when we are testing migrating to ancestry
  def self.column_options(force_allow_nil: false)
    @column_options ||=
      if ltree?
        {
          :default => '',
          :null  => false
        }
      elsif array?
        {
          :default => [],
          :null  => false
        }
      elsif column_type == "string"
        {
          :collation => ancestry_collation == "default" ? nil : ancestry_collation,
          :null  => !(materialized_path2? || materialized_path3?)
        }
      else
        {
          :limit => 3000,
          :null  => !(materialized_path2? || materialized_path3?)
        }
      end
    force_allow_nil ? @column_options.merge(:null => true) : @column_options
  end

  def self.with_model(options = {})
    depth                = options.delete(:depth) || 0
    width                = options.delete(:width) || 0
    skip_ancestry        = options.delete(:skip_ancestry)
    extra_columns        = options.delete(:extra_columns)
    default_scope_params = options.delete(:default_scope_params)

    options[:ancestry_column] ||= ancestry_column
    table_options = {}
    table_options[:id] = options.delete(:id) if options.key?(:id)

    ActiveRecord::Base.connection.create_table 'test_nodes', **table_options do |table|
      if skip_ancestry
        # Create a plain nullable column for tests that call has_ancestry later
        if ltree?
          table.column options[:ancestry_column], :ltree, default: '', null: true
        elsif array?
          table.integer options[:ancestry_column], array: true, default: [], null: true
        else
          table.send column_type, options[:ancestry_column], **column_options(force_allow_nil: true)
        end
        if options[:counter_cache]
          counter_col = options[:counter_cache] == true ? :children_count : options[:counter_cache]
          table.integer counter_col, default: 0, null: false
        end
      else
        table.ancestry options[:ancestry_column],
          format: options[:ancestry_format],
          cache_depth: options[:cache_depth],
          parent: options[:parent],
          root: options[:root],
          counter_cache: options[:counter_cache]
      end

      extra_columns&.each do |name, type|
        table.send type, name
      end
    end

    testmethod = caller[0].match(/[`'](?:[^#]*#)?([^']*)'/)[1]
    model_name = "#{testmethod.camelize}TestNode"

    begin
      model = Class.new(ActiveRecord::Base)
      const_set model_name, model

      model.table_name = 'test_nodes'

      if default_scope_params.present?
        model.send :default_scope, lambda { model.where(default_scope_params) }
      end

      if options[:ancestry_format]
        model.reset_column_information
      end
      model.has_ancestry options unless skip_ancestry
      if options[:ancestry_format]
        model.reset_column_information
      end

      if depth > 0
        yield model, create_test_nodes(model, depth, width)
      else
        yield model
      end
    ensure
      model.reset_column_information
      ActiveRecord::Base.connection.drop_table 'test_nodes'
      remove_const model_name
    end
  end

  def self.create_test_nodes(model, depth, width, parent = nil)
    if depth == 0
      []
    else
      Array.new width do
        node = model.create!(:parent => parent)
        [node, create_test_nodes(model, depth - 1, width, node)]
      end
    end
  end

  def self.postgres?
    db_type == "pg"
  end

  def self.mysql?
    db_type == "mysql2"
  end

  # SQLite virtual columns require Rails 7.2+ (PR #49346), PG/MySQL require 7.0+
  def self.virtual_columns?
    if postgres? || mysql?
      ActiveRecord.version.to_s >= "7.0"
    else
      ActiveRecord.version.to_s >= "7.2"
    end
  end

  def self.materialized_path?
    return @materialized_path if defined?(@materialized_path)

    @materialized_path = (ENV["FORMAT"].to_s == "" || ENV["FORMAT"].to_s == "materialized_path")
  end

  def self.materialized_path2?
    return @materialized_path2 if defined?(@materialized_path2)

    @materialized_path2 = (ENV["FORMAT"] == "materialized_path2")
  end

  def self.materialized_path3?
    return @materialized_path3 if defined?(@materialized_path3)

    @materialized_path3 = (ENV["FORMAT"] == "materialized_path3")
  end

  def self.ltree?
    return @ltree if defined?(@ltree)

    @ltree = (ENV["FORMAT"] == "ltree")
  end

  def self.array?
    return @array if defined?(@array)

    @array = (ENV["FORMAT"] == "array")
  end

  # Normalize DB env var to match database.yml keys
  def self.db_type
    case ENV.fetch("DB", "sqlite3")
    when "sqlite", "sqlite3" then "sqlite3"
    when "pg", "postgresql"  then "pg"
    when "mysql", "mysql2"   then "mysql2"
    else
      ENV["DB"]
    end
  end

  def self.connection_options
    @connection_options ||=
      begin
        if defined?(I18n)
          I18n.enforce_available_locales = false if I18n.respond_to?(:enforce_available_locales=)
        end

        filename = if File.exist?(File.expand_path('../database.yml', __FILE__))
                     File.expand_path('../database.yml', __FILE__)
                   else
                     File.expand_path('../database.ci.yml', __FILE__)
                   end

        yaml = ERB.new(File.read(filename)).result

        all_config =
          if YAML.respond_to?(:safe_load)
            YAML.safe_load(yaml, aliases: true)
          else
            YAML.load(yaml)
          end

        # Setup database connection
        config = all_config[db_type]
        if config.blank?
          $stderr.puts "", "", "ERROR: Could not find '#{db_type}' in #{filename}"
          $stderr.puts "Pick from: #{all_config.keys.join(", ")}", "", ""
          exit(1)
        end

        config
      end
  end

  def self.create
    ActiveRecord::Base.establish_connection(connection_options.except("database"))
    ActiveRecord::Base.connection.create_database(connection_options["database"])
    self
  end

  def self.drop
    ActiveRecord::Base.establish_connection(connection_options.except("database"))
    ActiveRecord::Base.connection.drop_database(connection_options["database"])
    self
  end

  def self.connect
    ActiveRecord::Base.establish_connection(connection_options)
    ActiveRecord::Base.connection # Check the connection works
    self
  end
end

# Only run setup and minitest when loaded for testing (not from Rakefile db tasks)
unless File.basename($PROGRAM_NAME) == "rake"
  require 'test_helpers'
  ActiveSupport.test_order = :random if ActiveSupport.respond_to?(:test_order=)
  ActiveSupport::TestCase.include(TestHelpers)

  AncestryTestDatabase.setup

  puts "\nLoaded Ancestry test suite environment:"
  puts "  Ruby: #{RUBY_VERSION}"
  puts "  ActiveRecord: #{ActiveRecord::VERSION::STRING}"
  puts "  Database: #{ActiveRecord::Base.connection.adapter_name}\n\n"

  require 'minitest/autorun'
end
