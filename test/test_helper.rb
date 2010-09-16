require 'test/unit'
require 'rubygems'
require 'active_record'
require 'ancestry'

ActiveRecord::Base.establish_connection :adapter  => "sqlite3",
                                        :database => ":memory:"

def setup_db
  # AR keeps printing annoying schema statements
  $stdout_orig = $stdout
  $stdout = StringIO.new

  ActiveRecord::Base.logger
  ActiveRecord::Schema.define(:version => 0) do
    create_table :test_nodes do |t|
      t.string :ancestry
      t.integer :depth_cache
      t.string :type
    end

    create_table :alternative_test_nodes do |t|
      t.string :alternative_ancestry
    end

    create_table :other_test_nodes do |t|
      t.string :ancestry
    end

    create_table :parent_id_test_nodes do |t|
      t.string :ancestry
      t.integer :parent_id
    end

    create_table :acts_as_tree_test_nodes do |t|
      t.string :ancestry
    end
  end

  $stdout = $stdout_orig
end

def teardown_db
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.drop_table(table)
  end
end

# In order for the `has_ancestry` scopes to make use of the Rails
# 3.1-compatible `where` method rather than use the old finder options, the
# scopes must be initialized *after* the database has been created.
#
# If `has_ancestry` is declared directly in the classes above before the test
# database has been created, ActiveRecord will complain and all tests will
# fail. Hence the reason for the `setup_ancestry` method which can be run
# after the database columns have been initialized.
#
def setup_ancestry
  TestNode.instance_eval do
    has_ancestry :cache_depth => true,
                 :depth_cache_column => :depth_cache
  end

  AlternativeTestNode.instance_eval do
    has_ancestry :ancestry_column => :alternative_ancestry,
                 :orphan_strategy => :rootify
  end

  ActsAsTreeTestNode.instance_eval do
    acts_as_tree
  end
end
