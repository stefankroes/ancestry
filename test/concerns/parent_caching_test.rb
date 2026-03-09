# frozen_string_literal: true

require_relative '../environment'

class ParentCachingTest < ActiveSupport::TestCase
  def test_parent_id_cache_on_create
    AncestryTestDatabase.with_model :depth => 3, :width => 3, :parent => true do |model, _roots|
      model.roots.each do |node|
        assert_nil node.read_attribute(:parent_id)
      end
      model.where.not(id: model.roots).each do |node|
        assert_equal node.ancestor_ids.last, node.read_attribute(:parent_id)
      end
    end
  end

  def test_parent_id_cache_after_move
    AncestryTestDatabase.with_model :depth => 3, :width => 2, :parent => true do |model, _roots|
      node = model.at_depth(2).first
      new_parent = model.roots.where.not(id: node.root_id).first
      node.update!(:parent => new_parent)

      node.reload
      assert_equal new_parent.id, node.read_attribute(:parent_id)
    end
  end

  def test_descendants_parent_id_unchanged_after_ancestor_move
    AncestryTestDatabase.with_model :depth => 4, :width => 2, :parent => true do |model, _roots|
      node = model.at_depth(1).first
      old_child = node.children.first

      new_parent = model.roots.where.not(id: node.root_id).first
      node.update!(:parent => new_parent)

      # The moved node's parent_id should change
      node.reload
      assert_equal new_parent.id, node.read_attribute(:parent_id)

      # But its child's parent_id should remain the same (still points to node)
      old_child.reload
      assert_equal node.id, old_child.read_attribute(:parent_id)
    end
  end

  def test_root_node_parent_id_is_nil
    AncestryTestDatabase.with_model :depth => 2, :width => 2, :parent => true do |model, _roots|
      model.roots.each do |root|
        assert_nil root.read_attribute(:parent_id)
      end
    end
  end

  def test_rebuild_parent_id_cache
    AncestryTestDatabase.with_model :depth => 3, :width => 3, :parent => true do |model, _roots|
      model.update_all(:parent_id => 0)
      model.rebuild_parent_id_cache!

      model.roots.each do |node|
        node.reload
        assert_nil node.read_attribute(:parent_id)
      end
      model.where.not(id: model.roots).each do |node|
        node.reload
        assert_equal node.ancestor_ids.last, node.read_attribute(:parent_id)
      end
    end
  end

  def test_rebuild_parent_id_cache_sql
    AncestryTestDatabase.with_model :depth => 3, :width => 3, :parent => true do |model, _roots|
      model.update_all(:parent_id => 0)
      model.rebuild_parent_id_cache_sql!

      model.roots.each do |node|
        node.reload
        assert_nil node.read_attribute(:parent_id)
      end
      model.where.not(id: model.roots).each do |node|
        node.reload
        assert_equal node.ancestor_ids.last, node.read_attribute(:parent_id)
      end
    end
  end
end
