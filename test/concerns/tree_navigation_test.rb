require_relative '../environment'

# this is testing attribute getters
class TreeNavigationTest < ActiveSupport::TestCase
  # yes, this is hardcoded. but got old redefininig it over and over again
  ATTRIBUTE_MATRIX = {
    ancestors:   {attribute_ids: :ancestor_ids,   exists: :ancestors?},
    children:    {attribute_ids: :child_ids,      exists: :children?},
    descendants: {attribute_ids: :descendant_ids},
    indirects:   {attribute_ids: :indirect_ids},
    siblings:    {attribute_ids: :sibling_ids,    exists: :siblings?},
    subtree:     {attribute_ids: :subtree_ids},
    path:        {attribute_ids: :path_ids},

    root:        {attribute_id: :root_id,         exists: :root?},
    parent:      {attribute_id: :parent_id,       exists: :parent?} #has_parent?, :ancestors?
  }

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

      # up:     |parent  |root       |ancestors|
      # down:   |children|descendants|indirects|
      # across: |siblings|subtree    |path     |

      # root: node1
      assert_attribute(nil, node1, :parent)
      refute node1.has_parent?
      assert_attribute(node1, node1, :root)
      assert_attributes([], node1, :ancestors)
      assert_attributes([node11, node12], node1, :children)
      assert_attributes([node11, node111, node12], node1, :descendants)
      assert_attributes([node111], node1, :indirects)
      assert_attributes([node1, node2], node1, :siblings)
      assert_attributes([node1, node11, node111, node12], node1, :subtree)
      assert_attributes([node1], node1, :path)
      assert_equal(0, node1.depth)

      # root: node11
      assert_attribute(node1, node11, :parent)
      assert node11.has_parent?
      assert_attribute(node1, node11, :root)
      assert_attributes([node1], node11, :ancestors)
      assert_attributes([node111], node11, :children)
      assert_attributes([node111], node11, :descendants)
      assert_attributes([], node11, :indirects)
      assert_attributes([node11, node12], node11, :siblings)
      assert_attributes([node11, node111], node11, :subtree)
      assert_attributes([node1, node11], node11, :path)
      assert_equal(1, node11.depth)

      # root: node111
      assert_attribute(node11, node111, :parent)
      assert node111.has_parent?
      assert_attribute(node1, node111, :root)
      assert_attributes([node1, node11], node111, :ancestors)
      assert_attributes([], node111, :children)
      assert_attributes([], node111, :descendants)
      assert_attributes([], node111, :indirects)
      assert_attributes([node111], node111, :siblings, exists: false)
      assert_attributes([node111], node111, :subtree)
      assert_attributes([node1, node11, node111], node111, :path)
      assert_equal(2, node111.depth)

      # root: node12
      assert_attribute(node1, node12, :parent)
      assert node12.has_parent?
      assert_attribute(node1, node12, :root)
      assert_attributes([node1], node12, :ancestors)
      assert_attributes([], node12, :children)
      assert_attributes([], node12, :descendants)
      assert_attributes([], node12, :indirects)
      assert_attributes([node11, node12], node12, :siblings)
      assert_attributes([node12], node12, :subtree)
      assert_attributes([node1, node12], node12, :path)
      assert_equal(1, node12.depth)

      # root: node2
      assert_attribute(nil, node2, :parent)
      refute node2.has_parent?
      assert_attribute(node2, node2, :root)
      assert_attributes([], node2, :ancestors)
      assert_attributes([node21], node2, :children)
      assert_attributes([node21], node2, :descendants)
      assert_attributes([], node2, :indirects)
      assert_attributes([node1, node2], node2, :siblings)
      assert_attributes([node2, node21], node2, :subtree)
      assert_attributes([node2], node2, :path)
      assert_equal(0, node2.depth)

      # root: node21
      assert_attribute(node2, node21, :parent)
      assert node21.has_parent?
      assert_attribute(node2, node21, :root)
      assert_attributes([node2], node21, :ancestors)
      assert_attributes([], node21, :children)
      assert_attributes([], node21, :descendants)
      assert_attributes([], node21, :indirects)
      assert_attributes([node21], node21, :siblings, exists: false)
      assert_attributes([node21], node21, :subtree)
      assert_attributes([node2, node21], node21, :path)
      assert_equal(1, node21.depth)
    end
  end

  def test_db_nodes
    AncestryTestDatabase.with_model do |model|
      root = model.create!
      node = model.new

      # new / not saved
      assert_equal [], node.ancestor_ids_in_database
      assert_equal [], node.ancestor_ids_before_last_save
      assert_nil node.parent_id
      assert_nil node.parent_id_in_database
      assert_nil node.parent_id_before_last_save

      # saved
      node.save!
      assert_equal [], node.ancestor_ids
      assert_equal [], node.ancestor_ids_in_database
      assert_equal [], node.ancestor_ids_before_last_save
      assert_nil node.parent_id
      assert_nil node.parent_id_in_database
      assert_nil node.parent_id_before_last_save

      # changed / not saved
      node.ancestor_ids = [root.id]
      assert_equal [root.id], node.ancestor_ids
      assert_equal [], node.ancestor_ids_in_database
      assert_equal [], node.ancestor_ids_before_last_save
      assert_equal root.id, node.parent_id
      assert_nil node.parent_id_in_database
      assert_nil node.parent_id_before_last_save

      # changed / saved
      node.save!
      assert_equal [root.id], node.ancestor_ids
      assert_equal [root.id], node.ancestor_ids_in_database
      assert_equal [], node.ancestor_ids_before_last_save # ?
      assert_equal root.id, node.parent_id
      assert_equal root.id, node.parent_id_in_database
      assert_nil node.parent_id_before_last_save # ?

      # reloaded
      node = model.find(node.id)
      assert_equal [root.id], node.ancestor_ids
      assert_equal [root.id], node.ancestor_ids_in_database
      assert_equal [], node.ancestor_ids_before_last_save # ?
      assert_equal root.id, node.parent_id
      assert_equal root.id, node.parent_id_in_database
      assert_nil node.parent_id_before_last_save # ?
    end
  end

  private

  def assert_attribute(value, node, attribute_name)
    attribute_id = "#{attribute_name}_id"
    if value.nil?
      assert_nil node.send(attribute_name)
      assert_nil node.send(attribute_id)
    else
      assert_equal value,     node.send(attribute_name)
      assert_equal value&.id, node.send(attribute_id)
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
  # @param attribute_name [String|Symbol|false] attribute to test
  # @param exists [true|false] (default values.present?) test the exists "attribute?
  def assert_attributes(values, node, attribute_name, exists: nil)
    attribute_ids = ATTRIBUTE_MATRIX[attribute_name][:attribute_ids]
    assert_equal values.map(&:id), node.send(attribute_name).order(:id).map(&:id)
    assert_equal values.map(&:id), node.send(attribute_ids).sort

    exists_name = ATTRIBUTE_MATRIX[attribute_name][:exists] or return

    exists = values.present? if exists.nil?
    if exists
      assert node.send(exists_name)
    else
      refute node.send(exists_name)
    end
  end
end
