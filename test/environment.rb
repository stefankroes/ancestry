require 'rubygems'

if ENV['ar'].nil?
  gem 'activerecord'
else 
  gem 'activerecord', ENV['ar']
end

require 'active_record'
require 'active_support/test_case'
require 'test/unit'
require 'ancestry'

class AncestryTestDatabase
  def self.setup
    ActiveRecord::Base.logger = ActiveSupport::BufferedLogger.new('log/test.log')
    ActiveRecord::Base.establish_connection YAML.load(File.open(File.join(File.dirname(__FILE__), 'database.yml')).read)[ENV['db'] || 'sqlite3']
  end

  def self.with_model options = {}
    depth            = options.delete(:depth) || 0
    width            = options.delete(:width) || 0
    extra_columns    = options.delete(:extra_columns)
    primary_key_type = options.delete(:primary_key_type) || :default

    ActiveRecord::Base.connection.create_table 'test_nodes', :id => (primary_key_type == :default) do |table|
      table.string :id, :null => false if primary_key_type == :string
      table.string options[:ancestry_column] || :ancestry
      table.integer options[:depth_cache_column] || :ancestry_depth if options[:cache_depth]
      extra_columns.each do |name, type|
        table.send type, name
      end unless extra_columns.nil?
    end

    begin
      model = Class.new(ActiveRecord::Base)
      (class << model; self; end).send :define_method, :model_name do; Struct.new(:human, :underscore, :i18n_key).new 'TestNode', 'test_node', 'test_node'; end
      const_set 'TestNode', model

      if primary_key_type == :string
        model.before_create { self.id = SecureRandom.hex(10) }
      end
      model.table_name = 'test_nodes'
      model.primary_key = :id if primary_key_type == :string
      model.has_ancestry options unless options.delete(:skip_ancestry)

      if depth > 0
        yield model, create_test_nodes(model, depth, width)
      else
        yield model
      end
    ensure
      model.reset_column_information
      ActiveRecord::Base.connection.drop_table 'test_nodes'
      remove_const 'TestNode'
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

