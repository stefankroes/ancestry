require 'rubygems'
require 'bundler/setup'

require 'simplecov'
require 'coveralls'
SimpleCov.formatter = Coveralls::SimpleCov::Formatter
SimpleCov.start do
  add_filter '/test/'
  add_filter '/vendor/'
end

require 'active_support'
require 'active_support/test_case'
ActiveSupport.test_order = :random if ActiveSupport.respond_to?(:test_order=)

require 'active_record'
require 'logger'

# Rails 3.2 has issues with mysql 5.7, primary key not being null.
# See https://stackoverflow.com/questions/33742967
if ActiveRecord::VERSION::MAJOR < 4
  begin
    require 'active_record/connection_adapters/mysql_adapter'
    ActiveRecord::ConnectionAdapters::MysqlAdapter
    class ActiveRecord::ConnectionAdapters::MysqlAdapter
      NATIVE_DATABASE_TYPES[:primary_key] = "int(11) auto_increment PRIMARY KEY"
    end
  rescue LoadError
    # not running with mysql, don't monkey patch
  end
end

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
    db_type =
      if ENV["BUNDLE_GEMFILE"] && ENV["BUNDLE_GEMFILE"] != File.expand_path("../../Gemfile", __FILE__)
        File.basename(ENV["BUNDLE_GEMFILE"]).split("_").first
      else
        "sqlite3"
      end
    config = YAML.load_file(filename)[db_type]
    ActiveRecord::Base.establish_connection config
    begin
      ActiveRecord::Base.connection
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

  def self.with_model options = {}
    depth                = options.delete(:depth) || 0
    width                = options.delete(:width) || 0
    extra_columns        = options.delete(:extra_columns)
    default_scope_params = options.delete(:default_scope_params)

    ActiveRecord::Base.connection.create_table 'test_nodes' do |table|
      table.string options[:ancestry_column] || :ancestry
      table.integer options[:depth_cache_column] || :ancestry_depth if options[:cache_depth]
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

      model.has_ancestry options unless options.delete(:skip_ancestry)

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
end

AncestryTestDatabase.setup

puts "\nLoaded Ancestry test suite environment:"
puts "  Ruby: #{RUBY_VERSION}"
puts "  ActiveRecord: #{ActiveRecord::VERSION::STRING}"
puts "  Database: #{ActiveRecord::Base.connection.adapter_name}\n\n"

require 'minitest/autorun' if ActiveSupport::VERSION::STRING > "4"
