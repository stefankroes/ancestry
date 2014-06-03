require File.expand_path('../../environment', __FILE__)

class DepthConstraintsTest < ActiveSupport::TestCase
  def test_descendants_with_depth_constraints
    AncestryTestDatabase.with_model :depth => 4, :width => 4, :cache_depth => true do |model, roots|
      assert_equal 4, model.roots.first.descendants(:before_depth => 2).count
      assert_equal 20, model.roots.first.descendants(:to_depth => 2).count
      assert_equal 16, model.roots.first.descendants(:at_depth => 2).count
      assert_equal 80, model.roots.first.descendants(:from_depth => 2).count
      assert_equal 64, model.roots.first.descendants(:after_depth => 2).count
    end
  end

  def test_subtree_with_depth_constraints
    AncestryTestDatabase.with_model :depth => 4, :width => 4, :cache_depth => true do |model, roots|
      assert_equal 5, model.roots.first.subtree(:before_depth => 2).count
      assert_equal 21, model.roots.first.subtree(:to_depth => 2).count
      assert_equal 16, model.roots.first.subtree(:at_depth => 2).count
      assert_equal 80, model.roots.first.subtree(:from_depth => 2).count
      assert_equal 64, model.roots.first.subtree(:after_depth => 2).count
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