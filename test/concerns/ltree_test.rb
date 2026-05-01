# frozen_string_literal: true

require_relative '../environment'

class LtreeTest < ActiveSupport::TestCase
  # Pure Ruby — no DB needed

  def test_parse_generate
    mod = Ancestry::Ltree
    assert_equal "",      mod.generate([])
    assert_equal "1",     mod.generate([1])
    assert_equal "1.2.3", mod.generate([1, 2, 3])

    assert_equal [],        mod.parse_integer("")
    assert_equal [1],       mod.parse_integer("1")
    assert_equal [1, 2, 3], mod.parse_integer("1.2.3")

    assert_equal [],         mod.parse("")
    assert_equal %w[a],     mod.parse("a")
    assert_equal %w[a b c], mod.parse("a.b.c")
  end

  # DB tests — require PostgreSQL with ltree extension

  def test_ancestry_column_ltree
    skip "requires PostgreSQL" unless AncestryTestDatabase.postgres?

    AncestryTestDatabase.with_model(ancestry_format: :ltree, ancestry_column: :tree_path) do |model|
      root = model.create!
      node = model.new

      # new node (default is "" not nil since ltree column has default)
      assert_equal "", node.tree_path
      assert_raises(Ancestry::AncestryException) { node.child_ancestry }

      # saved
      node.save!
      assert_equal "", node.tree_path
      assert_equal node.id.to_s, node.child_ancestry

      # changed
      node.ancestor_ids = [root.id]
      assert_equal root.id.to_s, node.tree_path
      assert_equal "", node.tree_path_in_database
      assert_equal node.id.to_s, node.child_ancestry

      # changed saved
      node.save!
      assert_equal root.id.to_s, node.tree_path
      assert_equal "#{root.id}.#{node.id}", node.child_ancestry

      # reloaded
      node.reload
      assert_equal root.id.to_s, node.tree_path
      assert_equal "#{root.id}.#{node.id}", node.child_ancestry

      # fresh node
      node = model.find(node.id)
      assert_equal root.id.to_s, node.tree_path
      assert_equal "#{root.id}.#{node.id}", node.child_ancestry
    end
  end

  def test_update_strategy_sql
    skip "requires PostgreSQL" unless AncestryTestDatabase.postgres?

    AncestryTestDatabase.with_model(ancestry_format: :ltree, ancestry_column: :tree_path, depth: 3, width: 1, update_strategy: :sql) do |model, _roots|
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
    skip "requires PostgreSQL" unless AncestryTestDatabase.postgres?

    AncestryTestDatabase.with_model(ancestry_format: :ltree, ancestry_column: :tree_path, depth: 2, width: 2, update_strategy: :sql) do |model, _roots|
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
    skip "requires PostgreSQL" unless AncestryTestDatabase.postgres?

    AncestryTestDatabase.with_model(ancestry_format: :ltree, ancestry_column: :tree_path) do |model|
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
