require_relative '../environment'

# this is testing attribute getters
class TreeNavigationTest < ActiveSupport::TestCase
  # up:     |parent  |root       |ancestors|
  # down:   |children|descendants|indirects|
  # across: |siblings|subtree    |path     |
  ATTRIBUTE_MATRIX = {
    root:        {attribute_id:  :root_id},
    parent:      {attribute_id:  :parent_id,     exists: :has_parent?, db: true},
    ancestors:   {attribute_ids: :ancestor_ids,  exists: :ancestors?,  db: true},
    children:    {attribute_ids: :child_ids,     exists: :children?},
    descendants: {attribute_ids: :descendant_ids},
    indirects:   {attribute_ids: :indirect_ids},
    siblings:    {attribute_ids: :sibling_ids,   exists: :siblings?},
    subtree:     {attribute_ids: :subtree_ids},
    path:        {attribute_ids: :path_ids, db: true},
  }
  # NOTE: has_ancestors? is an alias for parent? / ancestors? but not tested

  # class level getters are in test/concerns/scopes_test.rb
  # depth tests are in test/concerns/depth_constraints_tests.rb
  def test_node_getters
    AncestryTestDatabase.with_model do |model|
      node1  = model.create!
      node11 = model.create!(:parent => node1)
      node111 = model.create!(:parent => node11)
      node12 = model.create!(:parent => node1)
      node2  = model.create!
      node21 = model.create!(:parent => node2)

      # root: node1
      assert_attribute  node1, :parent, nil
      assert_attribute  node1, :root, node1
      assert_attributes node1, :ancestors, []
      assert_attributes node1, :children, [node11, node12]
      assert_attributes node1, :descendants, [node11, node111, node12]
      assert_attributes node1, :indirects, [node111]
      assert_attributes node1, :siblings, [node1, node2]
      assert_attributes node1, :subtree, [node1, node11, node111, node12]
      assert_attributes node1, :path, [node1]
      assert_equal(0, node1.depth)
      assert node1.root?

      # root: node11
      assert_attribute  node11, :parent, node1
      assert_attribute  node11, :root, node1
      assert_attributes node11, :ancestors, [node1]
      assert_attributes node11, :children, [node111]
      assert_attributes node11, :descendants, [node111]
      assert_attributes node11, :indirects, []
      assert_attributes node11, :siblings, [node11, node12]
      assert_attributes node11, :subtree, [node11, node111]
      assert_attributes node11, :path, [node1, node11]
      assert_equal(1, node11.depth)
      refute node11.root?

      # root: node111
      assert_attribute node111, :parent, node11
      assert_attribute node111, :root, node1
      assert_attributes node111, :ancestors, [node1, node11]
      assert_attributes node111, :children, []
      assert_attributes node111, :descendants, []
      assert_attributes node111, :indirects, []
      assert_attributes node111, :siblings, [node111], exists: false
      assert_attributes node111, :subtree, [node111]
      assert_attributes node111, :path, [node1, node11, node111]
      assert_equal(2, node111.depth)
      refute node111.root?

      # root: node12
      assert_attribute node12, :parent, node1
      assert_attribute node12, :root, node1
      assert_attributes node12, :ancestors, [node1]
      assert_attributes node12, :children, []
      assert_attributes node12, :descendants, []
      assert_attributes node12, :indirects, []
      assert_attributes node12, :siblings, [node11, node12]
      assert_attributes node12, :subtree, [node12]
      assert_attributes node12, :path, [node1, node12]
      assert_equal(1, node12.depth)
      refute node12.root?

      # root: node2
      assert_attribute node2, :parent, nil
      assert_attribute node2, :root, node2
      assert_attributes node2, :ancestors, []
      assert_attributes node2, :children, [node21]
      assert_attributes node2, :descendants, [node21]
      assert_attributes node2, :indirects, []
      assert_attributes node2, :siblings, [node1, node2]
      assert_attributes node2, :subtree, [node2, node21]
      assert_attributes node2, :path, [node2]
      assert_equal(0, node2.depth)
      assert node2.root?

      # root: node21
      assert_attribute node21, :parent, node2
      assert_attribute node21, :root, node2
      assert_attributes node21, :ancestors, [node2]
      assert_attributes node21, :children, []
      assert_attributes node21, :descendants, []
      assert_attributes node21, :indirects, []
      assert_attributes node21, :siblings, [node21], exists: false
      assert_attributes node21, :subtree, [node21]
      assert_attributes node21, :path, [node2, node21]
      assert_equal(1, node21.depth)
      refute node21.root?
    end
  end

  def test_node_in_db_first_node
    AncestryTestDatabase.with_model do |model|
      root = model.create!
      node = model.new

      # new / not saved
      assert_attributes node, :ancestors, []
      # assert_attributes([nil], node, :path) # not valid yet
      assert_attribute node, :parent, nil

      # saved
      node.save!
      assert_attributes node, :ancestors, []
      assert_attributes node, :path, [node]
      assert_attribute node, :parent, nil

      # changed / not saved
      node.ancestor_ids = [root.id]
      assert_attributes node, :ancestors, [root], db: []
      assert_attributes node, :path, [root, node], db: [node]
      assert_attribute node, :parent, root, db: nil

      # changed / saved
      node.save!
      node = model.find(node.id)
      assert_attributes node, :ancestors, [root]
      assert_attributes node, :path, [root, node]
      assert_attribute node, :parent, root

      # reloaded
      node = model.find(node.id)
      assert_attributes node, :ancestors, [root]
      assert_attributes node, :path, [root, node]
      assert_attribute node, :parent, root
    end
  end

  # kinda same as last test, more concerned with children
  def test_node_in_database_children
    AncestryTestDatabase.with_model do |model|
      node1   = model.create!
      node11  = node1.children.create!
      node111 = node11.children.create!
      node2   = model.create!

      # parent
      assert_attributes node1, :ancestors, []
      assert_attributes node1, :children, [node11]
      assert_attributes node1, :descendants, [node11, node111]
      assert_attributes node1, :indirects, [node111]

      # non-parent
      assert_attributes node2, :ancestors, []
      assert_attributes node2, :children, []
      assert_attributes node2, :descendants, []
      assert_attributes node2, :indirects, []

      # node
      assert_attributes node11, :ancestors, [node1]
      assert_attributes node11, :children, [node111]
      assert_attributes node11, :descendants, [node111]

      # changed (not saved)
      node11.parent = node2
      # reloads?

      # old parent (not saved)
      assert_attributes node1, :ancestors, []
      assert_attributes node1, :children, [node11]
      assert_attributes node1, :descendants, [node11, node111]
      assert_attributes node1, :indirects, [node111]

      # new parent (not saved)
      assert_attributes node2, :ancestors, []
      assert_attributes node2, :children, []
      assert_attributes node2, :descendants, []
      assert_attributes node2, :indirects, []

      # node (not saved)
      assert_attributes node11, :ancestors, [node2], db: [node1]
      assert_attributes node11, :children, [node111]
      assert_attributes node11, :descendants, [node111]

      # in database (again - but in a different hierarchy)
      node11.save!
      node1.reload ; node2.reload
      # are these necessary?
      # do we want this to work without?

      # old parent (saved)
      assert_attributes node1, :ancestors, []
      assert_attributes node1, :children, []
      assert_attributes node1, :descendants, []
      assert_attributes node1, :indirects, []

      # new parent (saved)
      assert_attributes node2, :ancestors, []
      assert_attributes node2, :children, [node11]
      assert_attributes node2, :descendants, [node11, node111]
      assert_attributes node2, :indirects, [node111]

      # node (saved)
      assert_attributes node11, :ancestors, [node2]
      assert_attributes node11, :children, [node111]
      assert_attributes node11, :descendants, [node111]
    end
  end

  # didn't know best way to test before_save values were correct.
  # hardcoding ids will break non-int id tests
  # please create PR or issue if you have a better idea
  def test_node_before_last_save
    AncestryTestDatabase.with_model do |model|
      skip "only written for integer keys" unless model.primary_key_is_an_integer?
      model.delete_all

      node1    = model.create!(:id => 1)
      node11   = node1.children.create!(:id => 2)
      node111  = node11.children.create!(:id => 3)
      node111.children.create!(:id => 4)
      node11.children.create!(:id => 5)
      node2    = model.create!(:id => 6)

      # loosing context in class_eval
      # basically rewriting minit-test.
      model.class_eval do
        def update_descendants_with_new_ancestry
          # only the top most node (node2 for us)
          # should be updating the ancestry for dependents
          if ancestry_callbacks_disabled?
            raise "callback disabled for #{id}" if id == 2
          else
            raise "callback eabled for #{id}" if id != 2
            # want to make sure we're pointing at the correct nodes
            actual = unscoped_descendants_before_last_save.order(:id).map(&:id)
            raise "unscoped_descendants_before_last_save was #{actual}" unless actual == [3, 4, 5]
            actual = path_ids_before_last_save
            raise "bad path_ids(before) is #{actual}" unless actual == [1, 2]
            actual = path_ids
            raise "bad path_ids is #{actual}" unless actual == [6, 2]
            actual = parent_id_before_last_save
            raise "bad parent_id(before) id #{actual}" unless actual == 1
            actual = parent_id
            raise "bad parent_id(before) id #{actual}" unless actual == 6
            actual = ancestor_ids_before_last_save
            raise "bad ancestor_ids(before) id #{actual}" unless actual == [1]
            actual = ancestor_ids
            raise "bad ancestor_ids(before) id #{actual}" unless actual == [6]
          end
          super
        end
      end

      node11.update(:parent => node2)
    end
  end

  private

  def assert_attribute(node, attribute_name, value, db: :value, exists: :value)
    attribute_id = ATTRIBUTE_MATRIX[attribute_name][:attribute_id]
    if value.nil?
      assert_nil node.send(attribute_name)
      assert_nil node.send(attribute_id)
    else
      assert_equal value,    node.send(attribute_name)
      assert_equal value.id, node.send(attribute_id)
    end

    if ATTRIBUTE_MATRIX[attribute_name][:db]
      attribute_db_name = "#{attribute_id}_in_database"
      db = value if db == :value
      if db.nil?
        assert_nil node.send(attribute_db_name)
      else
        assert_equal db.id, node.send(attribute_db_name)
      end
    end

    exists_name = ATTRIBUTE_MATRIX[attribute_name][:exists] or return

    exists = value.present? if exists == :value
    if exists
      assert node.send(exists_name)
    else
      refute node.send(exists_name)
    end
  end

  # this is a short form for assert_eaual
  # It tests the attribute, attribute_ids, and the attribute? method
  # the singular vs plural form is not consistent and so attribute_ids is needed in many cases
  #
  # when testing db tests (attribute_in_database) only the attribute_ids is tested
  # so attribute_name = false is passed in
  #
  # @param value [Array] expected output
  # @param attribute_name [Symbol] attribute to test
  # @param exists [true|false] test the exists "attribute? (default values.present?)
  # @param db [Array[AR]]  value that should be reflected _in_database (default: use values) 
  #                        skips if not supported in matrix
  def assert_attributes(node, attribute_name, values, db: :values, exists: :values)
    attribute_ids = ATTRIBUTE_MATRIX[attribute_name][:attribute_ids]
    assert_equal values.map(&:id), node.send(attribute_name).order(:id).map(&:id)
    assert_equal values.map(&:id), node.send(attribute_ids).sort

    if ATTRIBUTE_MATRIX[attribute_name][:db]
      db = values if db == :values
      attribute_db_name = "#{attribute_ids}_in_database"
      assert_equal db.map(&:id), node.send(attribute_db_name).sort
    end

    exists_name = ATTRIBUTE_MATRIX[attribute_name][:exists] or return

    exists = values.present? if exists == :values
    if exists
      assert node.send(exists_name)
    else
      refute node.send(exists_name)
    end
  end
end
