# frozen_string_literal: true

require_relative '../environment'

class LeavesTest < ActiveSupport::TestCase
  def test_leaf_on_leaf_node
    AncestryTestDatabase.with_model(depth: 3, width: 2) do |_model, roots|
      leaf = roots.first.last.first.last.first.first
      assert leaf.leaf?, "leaf node should be a leaf"
      assert leaf.is_childless?
    end
  end

  def test_leaf_on_parent_node
    AncestryTestDatabase.with_model(depth: 3, width: 2) do |_model, roots|
      root = roots.first.first
      refute root.leaf?, "root with children should not be a leaf"
    end
  end

  def test_leaf_on_root_without_children
    AncestryTestDatabase.with_model do |model|
      root = model.create!
      assert root.leaf?, "root without children should be a leaf"
    end
  end

  def test_class_leaves_scope
    AncestryTestDatabase.with_model(depth: 3, width: 2) do |model, _roots|
      leaves = model.leaves.order(:id).to_a
      expected = model.all.select(&:is_childless?).sort_by(&:id)

      assert_equal expected, leaves
      assert leaves.all?(&:is_childless?), "all returned nodes should be childless"
      assert leaves.none?(&:has_children?), "no returned nodes should have children"
    end
  end

  def test_class_leaves_returns_only_childless
    AncestryTestDatabase.with_model do |model|
      root = model.create!
      child1 = model.create!(parent: root)
      child2 = model.create!(parent: root)
      _grandchild = model.create!(parent: child1)

      leaves = model.leaves.order(:id).to_a
      assert_equal [child2, _grandchild].sort_by(&:id), leaves.sort_by(&:id)
    end
  end

  def test_instance_leaves
    AncestryTestDatabase.with_model do |model|
      root = model.create!
      child1 = model.create!(parent: root)
      child2 = model.create!(parent: root)
      grandchild1 = model.create!(parent: child1)
      grandchild2 = model.create!(parent: child1)

      assert_equal [child2, grandchild1, grandchild2].map(&:id).sort, root.leaf_ids.sort
      assert_equal [grandchild1, grandchild2].map(&:id).sort, child1.leaf_ids.sort
      assert_equal [], child2.leaf_ids
    end
  end

  def test_leaves_on_single_node
    AncestryTestDatabase.with_model do |model|
      root = model.create!
      assert_equal [], root.leaf_ids, "single node has no descendants, so no leaves"
    end
  end

  def test_leaves_scope_is_chainable
    AncestryTestDatabase.with_model(depth: 3, width: 2) do |model, _roots|
      count = model.leaves.count
      assert count > 0, "should have some leaves"
      assert_equal count, model.leaves.where.not(id: nil).count, "scope should be chainable"
    end
  end
end
