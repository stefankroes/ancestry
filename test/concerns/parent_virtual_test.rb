# frozen_string_literal: true

require_relative '../environment'

class ParentVirtualTest < ActiveSupport::TestCase
  def test_parent_id_virtual_on_create
    assert true, "only runs for postgres and recent rails versions"
    return unless only_test_virtual_column?

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
    assert true, "only runs for postgres and recent rails versions"
    return unless only_test_virtual_column?

    AncestryTestDatabase.with_model :depth => 3, :width => 2, :parent => :virtual do |model, _roots|
      node = model.at_depth(2).first
      new_parent = model.roots.where.not(id: node.root_id).first
      node.update!(:parent => new_parent)

      node.reload
      assert_equal new_parent.id, node.read_attribute(:parent_id)
    end
  end

  def test_descendants_parent_id_virtual_unchanged_after_ancestor_move
    assert true, "only runs for postgres and recent rails versions"
    return unless only_test_virtual_column?

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

  private

  def only_test_virtual_column?
    AncestryTestDatabase.postgres? && ActiveRecord.version.to_s >= "7.0"
  end
end
