require 'rubygems'
require 'bundler/setup'

require 'active_record'
require 'active_support/test_case'
require 'test/unit'

# this is to make absolutely sure we test this one, not the one
# installed on the system.
require File.expand_path('../../lib/ancestry', __FILE__)

require 'debugger' if RUBY_VERSION =~ /\A1.9/

class AncestryTestDatabase
  def self.setup
    ActiveRecord::Base.logger = ActiveSupport::BufferedLogger.new('log/test.log')
    ActiveRecord::Base.establish_connection YAML.load(File.open(File.expand_path('../database.yml', __FILE__)).read)[ENV['db'] || 'sqlite3']
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
      model.send :default_scope, default_scope_params if default_scope_params.present?

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

puts "\nRunning Ancestry test suite:"
puts "  Ruby: #{RUBY_VERSION}"
puts "  ActiveRecord: #{ActiveRecord::VERSION::STRING}"
puts "  Database: #{ActiveRecord::Base.connection.adapter_name}\n\n"

