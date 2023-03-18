require_relative '../environment'

# this is testing attribute getters
class TreeNavigationTest < ActiveSupport::TestCase
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
      assert_attributes([], node1, :ancestors, :ancestor_ids)
      assert_attributes([node11, node12], node1, :children, :child_ids)
      assert_attributes([node11, node111, node12], node1, :descendants, :descendant_ids, false)
      assert_attributes([node111], node1, :indirects, :indirect_ids, false)
      assert_attributes([node1, node2], node1, :siblings, :sibling_ids)
      assert_attributes([node1, node11, node111, node12], node1, :subtree, :subtree_ids, false)
      assert_attributes([node1], node1, :path, nil, false)
      assert_equal(0, node1.depth)

      # root: node11
      assert_attribute(node1, node11, :parent)
      assert node11.has_parent?
      assert_attribute(node1, node11, :root)
      assert_attributes([node1], node11, :ancestors, :ancestor_ids)
      assert_attributes([node111], node11, :children, :child_ids)
      assert_attributes([node111], node11, :descendants, :descendant_ids, false)
      assert_attributes([], node11, :indirects, :indirect_ids, false)
      assert_attributes([node11, node12], node11, :siblings, :sibling_ids)
      assert_attributes([node11, node111], node11, :subtree, :subtree_ids, false)
      assert_attributes([node1, node11], node11, :path, nil, false)
      assert_equal(1, node11.depth)

      # root: node111
      assert_attribute(node11, node111, :parent)
      assert node111.has_parent?
      assert_attribute(node1, node111, :root)
      assert_attributes([node1, node11], node111, :ancestors, :ancestor_ids)
      assert_attributes([], node111, :children, :child_ids)
      assert_attributes([], node111, :descendants, :descendant_ids, false)
      assert_attributes([], node111, :indirects, :indirect_ids, false)
      assert_attributes([node111], node111, :siblings, :sibling_ids, false)
      refute node111.siblings?
      assert_attributes([node111], node111, :subtree, :subtree_ids, false)
      assert_attributes([node1, node11, node111], node111, :path, nil, false)
      assert_equal(2, node111.depth)

      # root: node12
      assert_attribute(node1, node12, :parent)
      assert node12.has_parent?
      assert_attribute(node1, node12, :root)
      assert_attributes([node1], node12, :ancestors, :ancestor_ids)
      assert_attributes([], node12, :children, :child_ids)
      assert_attributes([], node12, :descendants, :descendant_ids, false)
      assert_attributes([], node12, :indirects, :indirect_ids, false)
      assert_attributes([node11, node12], node12, :siblings, :sibling_ids, false)
      refute node111.siblings?
      assert_attributes([node12], node12, :subtree, :subtree_ids, false)
      assert_attributes([node1, node12], node12, :path, nil, false)
      assert_equal(1, node12.depth)

      # root: node2
      assert_attribute(nil, node2, :parent)
      refute node2.has_parent?
      assert_attribute(node2, node2, :root)
      assert_attributes([], node2, :ancestors, :ancestor_ids)
      assert_attributes([node21], node2, :children, :child_ids)
      assert_attributes([node21], node2, :descendants, :descendant_ids, false)
      assert_attributes([], node2, :indirects, :indirect_ids, false)
      assert_attributes([node1, node2], node2, :siblings, :sibling_ids)
      assert_attributes([node2, node21], node2, :subtree, :subtree_ids, false)
      assert_attributes([node2], node2, :path, nil, false)
      assert_equal(0, node2.depth)

      # root: node21
      assert_attribute(node2, node21, :parent)
      assert node21.has_parent?
      assert_attribute(node2, node21, :root)
      assert_attributes([node2], node21, :ancestors, :ancestor_ids)
      assert_attributes([], node21, :children, :child_ids)
      assert_attributes([], node21, :descendants, :descendant_ids, false)
      assert_attributes([], node21, :indirects, :indirect_ids, false)
      assert_attributes([node21], node21, :siblings, :sibling_ids, false)
      refute node111.siblings?
      assert_attributes([node21], node21, :subtree, :subtree_ids, false)
      assert_attributes([node2, node21], node21, :path, nil, false)
      assert_equal(1, node21.depth)
    end
  end

  private

  def assert_attribute(value, node, attribute_name, attrid = nil)
    if value.nil?
      assert_nil node.send(attribute_name)
      assert_nil node.send(attrid || "#{attribute_name}_id")
    else
      assert_equal value,     node.send(attribute_name)
      assert_equal value&.id, node.send(attrid || "#{attribute_name}_id")
    end
  end

  def assert_attributes(values, node, attribute_name, attrid = nil, attrQ = nil)
    assert_equal values.map(&:id), node.send(attribute_name).order(:id).map(&:id)
    assert_equal values.map(&:id), node.send(attrid || "#{attribute_name}_ids").sort
    if values.empty? && attrQ != false
      refute node.send(attrQ || "#{attribute_name}?")
    elsif attrQ != false
      assert node.send(attrQ || "#{attribute_name}?")
    end
  end
end
