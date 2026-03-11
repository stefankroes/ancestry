# frozen_string_literal: true

require_relative '../environment'

class ParentVirtualTest < ActiveSupport::TestCase
  def test_parent_id_virtual_on_create
    return unless AncestryTestDatabase.virtual_columns?

    AncestryTestDatabase.with_model :depth => 3, :width => 3, :parent => :virtual do |model, _roots|
      model.roots.each do |node|
        assert_nil node.read_attribute(:parent_id)
      end
      model.where.not(id: model.roots).each do |node|
        assert_equal node.ancestor_ids.last, node.read_attribute(:parent_id)
      end
    end
  end

  def test_parent_id_virtual_after_move
    return unless AncestryTestDatabase.virtual_columns?

    AncestryTestDatabase.with_model :depth => 3, :width => 2, :parent => :virtual do |model, _roots|
      node = model.at_depth(2).first
      new_parent = model.roots.where.not(id: node.root_id).first
      node.update!(:parent => new_parent)

      node.reload
      assert_equal new_parent.id, node.read_attribute(:parent_id)
    end
  end

  def test_parent_of_parent_virtual_join
    return unless AncestryTestDatabase.virtual_columns?

    AncestryTestDatabase.with_model :depth => 3, :width => 2, :parent => :virtual do |model, _roots|
      # joins(:parent) self-joins with a table alias, then we filter on the
      # joined table's virtual parent_id column — verifies table-qualified
      # virtual columns work in SQL across all databases
      grandchildren = model.joins(:parent).where.not(parent: {parent_id: nil})

      assert grandchildren.count > 0
      grandchildren.each do |grandchild|
        assert_equal grandchild.ancestor_ids[-2], grandchild.parent.read_attribute(:parent_id)
      end
    end
  end

  def test_descendants_parent_id_virtual_unchanged_after_ancestor_move
    return unless AncestryTestDatabase.virtual_columns?

    AncestryTestDatabase.with_model :depth => 4, :width => 2, :parent => :virtual do |model, _roots|
      node = model.at_depth(1).first
      old_child = node.children.first

      new_parent = model.roots.where.not(id: node.root_id).first
      node.update!(:parent => new_parent)

      node.reload
      assert_equal new_parent.id, node.read_attribute(:parent_id)

      old_child.reload
      assert_equal node.id, old_child.read_attribute(:parent_id)
    end
  end
end
