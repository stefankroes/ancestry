require_relative '../environment'

class DepthConstraintsTest < ActiveSupport::TestCase
  def test_descendants_with_depth_constraints
    AncestryTestDatabase.with_model :depth => 4, :width => 4, :cache_depth => true do |model, _roots|
      root = model.roots.first
      assert_equal  4, root.descendants(:before_depth => 2).count
      assert_equal 20, root.descendants(:to_depth => 2).count
      assert_equal 16, root.descendants(:at_depth => 2).count
      assert_equal 80, root.descendants(:from_depth => 2).count
      assert_equal 64, root.descendants(:after_depth => 2).count

      assert_equal  4, root.descendant_ids(:before_depth => 2).count
      assert_equal 20, root.descendant_ids(:to_depth => 2).count
      assert_equal 16, root.descendant_ids(:at_depth => 2).count
      assert_equal 80, root.descendant_ids(:from_depth => 2).count
      assert_equal 64, root.descendant_ids(:after_depth => 2).count
    end
  end

  def test_subtree_with_depth_constraints
    AncestryTestDatabase.with_model :depth => 4, :width => 4, :cache_depth => true do |model, _roots|
      root = model.roots.first
      assert_equal  5, root.subtree(:before_depth => 2).count
      assert_equal 21, root.subtree(:to_depth => 2).count
      assert_equal 16, root.subtree(:at_depth => 2).count
      assert_equal 80, root.subtree(:from_depth => 2).count
      assert_equal 64, root.subtree(:after_depth => 2).count

      assert_equal  5, root.subtree_ids(:before_depth => 2).count
      assert_equal 21, root.subtree_ids(:to_depth => 2).count
      assert_equal 16, root.subtree_ids(:at_depth => 2).count
      assert_equal 80, root.subtree_ids(:from_depth => 2).count
      assert_equal 64, root.subtree_ids(:after_depth => 2).count
    end
  end

  def test_ancestors_with_depth_constraints
    AncestryTestDatabase.with_model :cache_depth => true do |model|
      node1 = model.create!
      node2 = node1.children.create!
      node3 = node2.children.create!
      node4 = node3.children.create!
      node5 = node4.children.create!
      leaf  = node5.children.create!

      assert_equal [node1, node2, node3],        leaf.ancestors(:before_depth => -2)
      assert_equal [node1, node2, node3, node4], leaf.ancestors(:to_depth => -2)
      assert_equal [node4],                      leaf.ancestors(:at_depth => -2)
      assert_equal [node4, node5],               leaf.ancestors(:from_depth => -2)
      assert_equal [node5],                      leaf.ancestors(:after_depth => -2)

      # currently ancestor_ids do not support option
    end
  end

  def test_indirects_with_depth_constraints
    AncestryTestDatabase.with_model :depth => 4, :width => 4, :cache_depth => true do |model, _roots|
      root = model.roots.first
      assert_equal  0, root.indirects(:before_depth => 2).count
      assert_equal 16, root.indirects(:to_depth => 2).count
      assert_equal 16, root.indirects(:at_depth => 2).count
      assert_equal 80, root.indirects(:from_depth => 2).count
      assert_equal 64, root.indirects(:after_depth => 2).count

      assert_equal  0, root.indirect_ids(:before_depth => 2).count
      assert_equal 16, root.indirect_ids(:to_depth => 2).count
      assert_equal 16, root.indirect_ids(:at_depth => 2).count
      assert_equal 80, root.indirect_ids(:from_depth => 2).count
      assert_equal 64, root.indirect_ids(:after_depth => 2).count
    end
  end

  def test_path_with_depth_constraints
    AncestryTestDatabase.with_model :cache_depth => true do |model|
      node1 = model.create!
      node2 = node1.children.create!
      node3 = node2.children.create!
      node4 = node3.children.create!
      node5 = node4.children.create!
      leaf  = node5.children.create!

      assert_equal [node1, node2, node3],        leaf.path(:before_depth => -2)
      assert_equal [node1, node2, node3, node4], leaf.path(:to_depth => -2)
      assert_equal [node4],                      leaf.path(:at_depth => -2)
      assert_equal [node4, node5, leaf],         leaf.path(:from_depth => -2)
      assert_equal [node5, leaf],                leaf.path(:after_depth => -2)
    end
  end
end
