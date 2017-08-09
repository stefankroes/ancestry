require_relative '../environment'

class ScopesTest < ActiveSupport::TestCase
  def test_scopes
    AncestryTestDatabase.with_model :depth => 3, :width => 3 do |model, roots|
      # Roots assertion
      assert_equal roots.map(&:first), model.roots.to_a

      model.all.each do |test_node|
        # Assertions for ancestors_of named scope
        assert_equal test_node.ancestors.to_a, model.ancestors_of(test_node).to_a
        assert_equal test_node.ancestors.to_a, model.ancestors_of(test_node.id).to_a
        # Assertions for children_of named scope
        assert_equal test_node.children.to_a, model.children_of(test_node).to_a
        assert_equal test_node.children.to_a, model.children_of(test_node.id).to_a
        # Assertions for descendants_of named scope
        assert_equal test_node.descendants.to_a, model.descendants_of(test_node).to_a
        assert_equal test_node.descendants.to_a, model.descendants_of(test_node.id).to_a
        # Assertions for subtree_of named scope
        assert_equal test_node.subtree.to_a, model.subtree_of(test_node).to_a
        assert_equal test_node.subtree.to_a, model.subtree_of(test_node.id).to_a
        # Assertions for siblings_of named scope
        assert_equal test_node.siblings.to_a, model.siblings_of(test_node).to_a
        assert_equal test_node.siblings.to_a, model.siblings_of(test_node.id).to_a
        # Assertions for path_of named scope
        assert_equal test_node.path.to_a, model.path_of(test_node).to_a
        assert_equal test_node.path.to_a, model.path_of(test_node.id).to_a
      end
    end
  end

  def test_order_by
    AncestryTestDatabase.with_model :depth => 3, :width => 3 do |model, roots|
      expected = model.all.sort_by { |m| [m.ancestry || "", m.id.to_i] }
      actual = model.ordered_by_ancestry_and(:id)
      assert_equal expected.map { |r| [r.ancestry, r.id.to_s] }, actual.map { |r| [r.ancestry, r.id.to_s] }
    end
  end

  def test_node_creation_through_scope
    AncestryTestDatabase.with_model do |model|
      node = model.create!
      child = node.children.create
      assert_equal node, child.parent

      other_child = child.siblings.create!
      assert_equal node, other_child.parent

      grandchild = model.children_of(child).new
      grandchild.save
      assert_equal child, grandchild.parent

      other_grandchild = model.siblings_of(grandchild).new
      other_grandchild.save!
      assert_equal child, other_grandchild.parent
    end
  end

  def test_scoping_in_callbacks
    AncestryTestDatabase.with_model do |model|
      record = model.create

      model.instance_eval do
        after_create :after_create_callback
      end

      model.class_eval do
        define_method :after_create_callback do
          # We don't want to be in the #children scope here when creating the child
          self.parent
          self.parent_id = record.id if record
          self.root
        end
      end

      parent = model.create
      assert parent.children.create
    end
  end
end
