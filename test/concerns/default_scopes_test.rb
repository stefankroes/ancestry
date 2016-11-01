require_relative '../environment'

class DefaultScopesTest < ActiveSupport::TestCase
  def test_node_excluded_by_default_scope_should_still_move_with_parent
    AncestryTestDatabase.with_model(
      :width => 3, :depth => 3, :extra_columns => {:deleted_at => :datetime},
      :default_scope_params => {:deleted_at => nil}
    ) do |model, roots|
      roots = model.roots.to_a
      grandparent = roots[0]
      new_grandparent = roots[1]
      parent = grandparent.children.first
      child = parent.children.first

      child.update_attributes :deleted_at => Time.now
      parent.update_attributes :parent => new_grandparent
      child.update_attributes :deleted_at => nil

      assert child.reload.ancestors.include? new_grandparent
      assert_equal new_grandparent, child.reload.ancestors.first
      assert_equal parent, child.reload.ancestors.last
    end
  end

  def test_node_excluded_by_default_scope_should_be_destroyed_with_parent
    AncestryTestDatabase.with_model(
      :width => 1, :depth => 2, :extra_columns => {:deleted_at => :datetime},
      :default_scope_params => {:deleted_at => nil},
      :orphan_strategy => :destroy
    ) do |model, roots|
      parent = model.roots.first
      child = parent.children.first

      child.update_attributes :deleted_at => Time.now
      parent.destroy
      child.update_attributes :deleted_at => nil

      assert model.count.zero?
    end
  end

  def test_node_excluded_by_default_scope_should_be_rootified
    AncestryTestDatabase.with_model(
      :width => 1, :depth => 2, :extra_columns => {:deleted_at => :datetime},
      :default_scope_params => {:deleted_at => nil},
      :orphan_strategy => :rootify
    ) do |model, roots|
      parent = model.roots.first
      child = parent.children.first

      child.update_attributes :deleted_at => Time.now
      parent.destroy
      child.update_attributes :deleted_at => nil

      assert child.reload.is_root?
    end
  end
end
