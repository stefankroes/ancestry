require 'rubygems'
require 'bundler/setup'

if ENV["COVERAGE"]
  require 'simplecov'
  SimpleCov.start do
    add_filter '/test/'
    add_filter '/vendor/'
  end
end

require 'active_support'
require 'active_support/test_case'
ActiveSupport.test_order = :random if ActiveSupport.respond_to?(:test_order=)

require 'active_record'
require 'logger'

# Make absolutely sure we are testing local ancestry
require File.expand_path('../../lib/ancestry', __FILE__)

class AncestryTestDatabase
  def self.setup
    # Silence I18n and Activerecord logging
    I18n.enforce_available_locales = false if I18n.respond_to? :enforce_available_locales=
    ActiveRecord::Base.logger = Logger.new(STDERR)
    ActiveRecord::Base.logger.level = Logger::Severity::UNKNOWN

    # Assume Travis CI database config if no custom one exists
    filename = if File.exist?(File.expand_path('../database.yml', __FILE__))
                 File.expand_path('../database.yml', __FILE__)
               else
                 File.expand_path('../database.ci.yml', __FILE__)
               end

    # Setup database connection
    all_config = if YAML.respond_to?(:safe_load_file)
      YAML.safe_load_file(filename, aliases: true)
    else
      YAML.load_file(filename)
    end
    config = all_config[db_type]
    if config.blank?
      $stderr.puts "","","ERROR: Could not find '#{db_type}' in #{filename}"
      $stderr.puts "Pick from: #{all_config.keys.join(", ")}", "", ""
      exit(1)
    end
    if ActiveRecord::VERSION::MAJOR >= 6
      ActiveRecord::Base.establish_connection(**config)
    else
      ActiveRecord::Base.establish_connection config
    end

    begin
      ActiveRecord::Base.connection
      Ancestry.default_update_strategy = ENV["UPDATE_STRATEGY"] == "sql" ? :sql : :ruby
      Ancestry.default_ancestry_format = ENV["FORMAT"].to_sym if ENV["FORMAT"].present?

      puts "testing #{db_type} #{Ancestry.default_update_strategy == :sql ? "(sql) " : ""}(with #{column_type} #{ancestry_column})"
      puts "column format: #{Ancestry.default_ancestry_format} options: #{column_options.inspect}"

    rescue => err
      if ENV["CI"]
        raise
      else
        puts "\nSkipping tests for '#{db_type}'"
        puts "  #{err}\n\n"
        exit 0
      end
    end
  end

  def self.column_type
    @column_type ||= ENV["ANCESTRY_COLUMN_TYPE"].presence || "string"
  end

  def self.ancestry_column
    @ancestry_column ||= ENV["ANCESTRY_COLUMN"].presence || "ancestry"
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
      if column_type == "string"
        {
          :collation => ancestry_collation == "default" ? nil : ancestry_collation,
          :null  => materialized_path2? ? false : true
        }
      else
        {
          :limit => 3000,
          :null  => materialized_path2? ? false : true
        }
      end
    force_allow_nil ? @column_options.merge(:null => true) : @column_options
  end

  def self.with_model options = {}
    depth                = options.delete(:depth) || 0
    width                = options.delete(:width) || 0
    skip_ancestry        = options.delete(:skip_ancestry)
    extra_columns        = options.delete(:extra_columns)
    default_scope_params = options.delete(:default_scope_params)

    options[:ancestry_column] ||= ancestry_column
    table_options={}
    table_options[:id] = options.delete(:id) if options.key?(:id)

    ActiveRecord::Base.connection.create_table 'test_nodes', **table_options do |table|
      table.send(column_type, options[:ancestry_column], **column_options(force_allow_nil: skip_ancestry))
      table.integer options[:cache_depth] == true ? :ancestry_depth : options[:cache_depth] if options[:cache_depth]
      if options[:counter_cache]
        counter_cache_column = options[:counter_cache] == true ? :children_count : options[:counter_cache]
        table.integer counter_cache_column
      end

      extra_columns.each do |name, type|
        table.send type, name
      end unless extra_columns.nil?
    end

    testmethod = caller[0][/`.*'/][1..-2]
    model_name = testmethod.camelize + "TestNode"

    begin
      model = Class.new(ActiveRecord::Base)
      const_set model_name, model

      model.table_name = 'test_nodes'

      if default_scope_params.present?
        model.send :default_scope, lambda { model.where(default_scope_params) }
      end

      model.has_ancestry options unless skip_ancestry

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

  def self.create_test_nodes model, depth, width, parent = nil
    unless depth == 0
      Array.new width do
        node = model.create!(:parent => parent)
        [node, create_test_nodes(model, depth - 1, width, node)]
      end
    else; []; end
  end

  def self.postgres?
    db_type == "pg"
  end

  def self.materialized_path2?
    return @materialized_path2 if defined?(@materialized_path2)
    @materialized_path2 = (ENV["FORMAT"] == "materialized_path2")
  end
  private

  def self.db_type
    ENV["DB"].presence || "sqlite3"
  end
end

AncestryTestDatabase.setup

puts "\nLoaded Ancestry test suite environment:"
puts "  Ruby: #{RUBY_VERSION}"
puts "  ActiveRecord: #{ActiveRecord::VERSION::STRING}"
puts "  Database: #{ActiveRecord::Base.connection.adapter_name}\n\n"

require 'minitest/autorun'
