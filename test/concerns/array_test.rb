# frozen_string_literal: true

require_relative '../environment'

class ArrayTest < ActiveSupport::TestCase
  # Pure Ruby — no DB needed

  def test_parse_generate
    mod = Ancestry::MaterializedPathArray
    assert_equal [],        mod.generate([])
    assert_equal [1],       mod.generate([1])
    assert_equal [1, 2, 3], mod.generate([1, 2, 3])

    assert_equal [],        mod.parse_integer([])
    assert_equal [1],       mod.parse_integer([1])
    assert_equal [1, 2, 3], mod.parse_integer([1, 2, 3])

    assert_equal [],         mod.parse([])
    assert_equal %w[1],     mod.parse([1])
    assert_equal %w[1 2 3], mod.parse([1, 2, 3])
  end

  def test_child_ancestry_value
    mod = Ancestry::MaterializedPathArray
    assert_equal [1],       mod.child_ancestry_value([], 1)
    assert_equal [1, 2],    mod.child_ancestry_value([1], 2)
    assert_equal [1, 2, 3], mod.child_ancestry_value([1, 2], 3)
  end

  # DB tests — require PostgreSQL (integer[] column type)

  def test_ancestry_column_array
    return unless AncestryTestDatabase.postgres?

    AncestryTestDatabase.with_model(ancestry_format: :array) do |model|
      root = model.create!
      child = model.create!(parent: root)
      grand = model.create!(parent: child)

      assert_equal [],                root.read_attribute(AncestryTestDatabase.ancestry_column)
      assert_equal [root.id],         child.read_attribute(AncestryTestDatabase.ancestry_column)
      assert_equal [root.id, child.id], grand.read_attribute(AncestryTestDatabase.ancestry_column)

      assert_equal [root.id, child.id], grand.ancestor_ids
      assert_equal child.id, grand.parent_id
      assert_equal root.id, grand.root_id
    end
  end

  def test_update_strategy_sql
    return unless AncestryTestDatabase.postgres?

    AncestryTestDatabase.with_model(ancestry_format: :array, depth: 3, width: 1, update_strategy: :sql) do |model, _roots|
      node = model.at_depth(1).first
      root = model.roots.first
      new_root = model.create!

      node.update!(parent: new_root)

      node.descendants.each do |descendant|
        assert descendant.ancestor_ids.include?(new_root.id),
          "descendant #{descendant.id} should include new root"
        refute descendant.ancestor_ids.include?(root.id),
          "descendant #{descendant.id} should not include old root"
      end
    end
  end

  def test_move_root_to_child_and_back_sql
    return unless AncestryTestDatabase.postgres?

    AncestryTestDatabase.with_model(ancestry_format: :array, depth: 2, width: 2, update_strategy: :sql) do |model, _roots|
      root = model.roots.first
      other_root = model.roots.last
      child = root.children.first

      # Move root under another root (old_ancestry blank, new is not)
      root.update!(parent: other_root)
      child.reload
      assert child.ancestor_ids.include?(other_root.id)

      # Move back to root (new_ancestry blank)
      root.reload
      root.update!(parent: nil)
      child.reload
      assert_equal [root.id], child.ancestor_ids
    end
  end

  def test_ancestry_validation_exclude_self
    return unless AncestryTestDatabase.postgres?

    AncestryTestDatabase.with_model(ancestry_format: :array) do |model|
      parent = model.create!
      child = parent.children.create!
      assert_raise ActiveRecord::RecordInvalid do
        parent.parent = child
        refute parent.sane_ancestor_ids?
        parent.save!
      end
    end
  end
end
