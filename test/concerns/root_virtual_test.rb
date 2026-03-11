# frozen_string_literal: true

require_relative '../environment'

class RootVirtualTest < ActiveSupport::TestCase
  # MySQL does not support virtual root_id — generated columns cannot
  # reference auto-increment columns, and root_id = id for root nodes.

  def test_root_id_virtual_on_create
    return if !AncestryTestDatabase.virtual_columns? || AncestryTestDatabase.mysql?

    AncestryTestDatabase.with_model :depth => 3, :width => 3, :root => :virtual do |model, _roots|
      model.all.each do |node|
        assert_equal node.root_id, node.read_attribute(:root_id)
      end
    end
  end

  def test_root_id_virtual_root_is_self
    return if !AncestryTestDatabase.virtual_columns? || AncestryTestDatabase.mysql?

    AncestryTestDatabase.with_model :depth => 2, :width => 2, :root => :virtual do |model, _roots|
      model.roots.each do |root|
        assert_equal root.id, root.read_attribute(:root_id)
      end
    end
  end

  def test_root_id_virtual_after_cross_tree_move
    return if !AncestryTestDatabase.virtual_columns? || AncestryTestDatabase.mysql?

    AncestryTestDatabase.with_model :depth => 3, :width => 2, :root => :virtual do |model, _roots|
      node = model.at_depth(1).first
      old_root_id = node.read_attribute(:root_id)
      new_parent = model.roots.where.not(id: old_root_id).first

      node.update!(:parent => new_parent)

      node.reload
      assert_equal new_parent.id, node.read_attribute(:root_id)

      node.descendants.each do |descendant|
        assert_equal new_parent.id, descendant.read_attribute(:root_id)
      end
    end
  end
end
