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

  # DB tests — require PostgreSQL (integer[] column type)

  def test_ancestry_column_array
    skip "requires PostgreSQL 7.0+" unless AncestryTestDatabase.postgres? && ActiveRecord::VERSION::STRING >= "7.0"

    AncestryTestDatabase.with_model(ancestry_format: :array, ancestry_column: :ancestor_ids) do |model|
      root = model.create!
      child = model.create!(parent: root)
      grand = model.create!(parent: child)

      assert_equal [],                  root.read_attribute(:ancestor_ids)
      assert_equal [root.id],           child.read_attribute(:ancestor_ids)
      assert_equal [root.id, child.id], grand.read_attribute(:ancestor_ids)

      assert_equal [root.id, child.id], grand.ancestor_ids
      assert_equal child.id, grand.parent_id
      assert_equal root.id, grand.root_id
    end
  end

  def test_update_strategy_sql
    skip "requires PostgreSQL 7.0+" unless AncestryTestDatabase.postgres? && ActiveRecord::VERSION::STRING >= "7.0"

    AncestryTestDatabase.with_model(ancestry_format: :array, ancestry_column: :ancestor_ids, depth: 3, width: 1, update_strategy: :sql) do |model, _roots|
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
    skip "requires PostgreSQL 7.0+" unless AncestryTestDatabase.postgres? && ActiveRecord::VERSION::STRING >= "7.0"

    AncestryTestDatabase.with_model(ancestry_format: :array, ancestry_column: :ancestor_ids, depth: 2, width: 2, update_strategy: :sql) do |model, _roots|
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
    skip "requires PostgreSQL 7.0+" unless AncestryTestDatabase.postgres? && ActiveRecord::VERSION::STRING >= "7.0"

    AncestryTestDatabase.with_model(ancestry_format: :array, ancestry_column: :ancestor_ids) do |model|
      parent = model.create!
      child = parent.children.create!
      assert_raise ActiveRecord::RecordInvalid do
        parent.parent = child
        refute parent.sane_ancestor_ids?
        parent.save!
      end
    end
  end

  def test_reparent_across_trees
    skip "requires PostgreSQL 7.0+" unless AncestryTestDatabase.postgres? && ActiveRecord::VERSION::STRING >= "7.0"

    AncestryTestDatabase.with_model(ancestry_format: :array, ancestry_column: :ancestor_ids, depth: 3, width: 3) do |model, roots|
      root1, root2, root3 = roots.map(&:first)

      root1.update!(parent: root2)
      root2.update!(parent: root3)

      expected_before = root3.descendants.size
      root1_subtree = root1.subtree.size

      root1.update!(parent: nil)

      assert_equal expected_before - root1_subtree, root3.descendants.size,
        "root3 should lose root1's subtree after root1 moves to root"
    end
  end
end
