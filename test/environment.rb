require 'rubygems'
require 'bundler/setup'
require 'active_record'
require 'active_support/test_case'
require 'active_support/buffered_logger'
require 'test/unit'
require 'debugger'
require 'coveralls'
require 'logger'

Coveralls.wear!

# Make absolutely sure we are testing local ancestry
require File.expand_path('../../lib/ancestry', __FILE__)

class AncestryTestDatabase
  def self.setup
    # Silence I18n and Activerecord logging
    I18n.enforce_available_locales = false if I18n.respond_to? :enforce_available_locales=
    ActiveRecord::Base.logger = Logger.new(STDERR)
    ActiveRecord::Base.logger.level = Logger::Severity::UNKNOWN

    # Assume Travis CI database config if no custom one exists
    filename = if File.exists?(File.expand_path('../database.yml', __FILE__))
      File.expand_path('../database.yml', __FILE__)
    else
      File.expand_path('../database.ci.yml', __FILE__)
    end

    # Setup database connection
    YAML.load(File.open(filename).read).values.each do |config|
      begin
        ActiveRecord::Base.establish_connection config
        break if ActiveRecord::Base.connection
      rescue LoadError, RuntimeError
        # Try if adapter can be loaded for next config
      end
    end
    raise 'Could not load any database adapter!' unless ActiveRecord::Base.connected?
  end

  def self.with_model options = {}
    depth                = options.delete(:depth) || 0
    width                = options.delete(:width) || 0
    extra_columns        = options.delete(:extra_columns)
    default_scope_params = options.delete(:default_scope_params)

    ActiveRecord::Base.connection.create_table 'test_nodes' do |table|
      table.string options[:ancestry_column] || :ancestry
      table.integer options[:depth_cache_column] || :ancestry_depth if options[:cache_depth]
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

        # Rails < 3.1 doesn't support lambda default_scopes (only hashes)
        # But Rails >= 4 logs deprecation warnings for hash default_scopes
        if ActiveRecord::VERSION::STRING < "3.1"
          model.send :default_scope, { :conditions => default_scope_params }
        else
          model.send :default_scope, lambda { model.where(default_scope_params) }
        end
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

