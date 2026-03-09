# frozen_string_literal: true

require_relative '../environment'

class RootCachingTest < ActiveSupport::TestCase
  def test_root_id_cache_on_create
    AncestryTestDatabase.with_model :depth => 3, :width => 3, :root => true do |model, _roots|
      model.all.each do |node|
        assert_equal node.root_id, node.read_attribute(:root_id)
      end
    end
  end

  def test_root_node_root_id_is_self
    AncestryTestDatabase.with_model :depth => 2, :width => 2, :root => true do |model, _roots|
      model.roots.each do |root|
        assert_equal root.id, root.read_attribute(:root_id)
      end
    end
  end

  def test_root_id_cache_after_same_tree_move
    AncestryTestDatabase.with_model :depth => 3, :width => 2, :root => true do |model, _roots|
      # Move within same tree — root_id should not change
      node = model.at_depth(2).first
      original_root_id = node.read_attribute(:root_id)
      new_parent = model.roots.find(original_root_id)
      node.update!(:parent => new_parent)

      node.reload
      assert_equal original_root_id, node.read_attribute(:root_id)
    end
  end

  def test_root_id_cache_after_cross_tree_move
    AncestryTestDatabase.with_model :depth => 3, :width => 2, :root => true do |model, _roots|
      node = model.at_depth(1).first
      old_root_id = node.read_attribute(:root_id)
      new_parent = model.roots.where.not(id: old_root_id).first

      node.update!(:parent => new_parent)

      # The moved node's root_id should change
      node.reload
      assert_equal new_parent.id, node.read_attribute(:root_id)
    end
  end

  def test_descendants_root_id_updated_after_cross_tree_move
    AncestryTestDatabase.with_model :depth => 4, :width => 2, :root => true, :update_strategy => :sql do |model, _roots|
      node = model.at_depth(1).first
      old_root_id = node.read_attribute(:root_id)
      new_parent = model.roots.where.not(id: old_root_id).first

      node.update!(:parent => new_parent)

      # All descendants should have the new root_id
      node.reload
      node.descendants.each do |descendant|
        assert_equal new_parent.id, descendant.read_attribute(:root_id),
          "descendant #{descendant.id} root_id should be #{new_parent.id}"
      end
    end
  end

  def test_descendants_root_id_unchanged_after_same_tree_move
    AncestryTestDatabase.with_model :depth => 4, :width => 2, :root => true, :update_strategy => :sql do |model, _roots|
      node = model.at_depth(2).first
      original_root_id = node.read_attribute(:root_id)
      new_parent = model.roots.find(original_root_id)
      node.update!(:parent => new_parent)

      node.descendants.each do |descendant|
        assert_equal original_root_id, descendant.read_attribute(:root_id)
      end
    end
  end

  def test_rebuild_root_id_cache
    AncestryTestDatabase.with_model :depth => 3, :width => 3, :root => true do |model, _roots|
      model.update_all(:root_id => 0)
      model.rebuild_root_id_cache!

      model.all.each do |node|
        node.reload
        assert_equal node.root_id, node.read_attribute(:root_id)
      end
    end
  end

  def test_rebuild_root_id_cache_sql
    AncestryTestDatabase.with_model :depth => 3, :width => 3, :root => true do |model, _roots|
      model.update_all(:root_id => 0)
      model.rebuild_root_id_cache_sql!

      model.all.each do |node|
        node.reload
        assert_equal node.root_id, node.read_attribute(:root_id)
      end
    end
  end
end
