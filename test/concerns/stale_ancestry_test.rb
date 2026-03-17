# frozen_string_literal: true

require_relative '../environment'

class StaleAncestryTest < ActiveSupport::TestCase
  # When node A moves, update_descendants changes B and C's ancestry in the DB
  # but not their Ruby objects. If B then moves without reload, its
  # path_ids_before_last_save is stale — update_descendants queries using the
  # wrong prefix and misses C, leaving it orphaned.
  #
  # The before_update :refresh_ancestry_from_database callback fixes this by
  # reading the real DB ancestry before the save, correcting dirty tracking.

  def test_cascading_move_without_reload
    AncestryTestDatabase.with_model do |model|
      # Tree: root -> a -> b -> c
      root = model.create!
      a = model.create!(parent: root)
      b = model.create!(parent: a)
      c = model.create!(parent: b)

      assert_equal [root.id, a.id, b.id], c.reload.ancestor_ids

      # Move a to root — updates b,c ancestry in DB, but not Ruby objects
      a.update!(parent: nil)

      # Verify b and c are updated in DB
      assert_equal [a.id], model.find(b.id).ancestor_ids
      assert_equal [a.id, b.id], model.find(c.id).ancestor_ids

      # b's Ruby object is stale (still thinks ancestry = root/a)
      # Move b to root WITHOUT reload
      b.update!(parent: nil)

      # c should now be a child of b (ancestry = [b.id])
      c_from_db = model.find(c.id)
      assert_equal [b.id], c_from_db.ancestor_ids,
        "c's ancestry should be [b] but was #{c_from_db.ancestor_ids.inspect} — stale ancestry bug"
      assert_equal b.id, c_from_db.parent_id
    end
  end

  def test_cascading_move_three_levels_without_reload
    AncestryTestDatabase.with_model do |model|
      # Tree: root -> a -> b -> c -> d
      root = model.create!
      a = model.create!(parent: root)
      b = model.create!(parent: a)
      c = model.create!(parent: b)
      d = model.create!(parent: c)

      # Move a to root
      a.update!(parent: nil)

      # Move b (stale) to root
      b.update!(parent: nil)

      # Move c (doubly stale) under root
      c.update!(parent: root)

      # d should be under c, under root
      d_from_db = model.find(d.id)
      assert_equal [root.id, c.id], d_from_db.ancestor_ids,
        "d's ancestry should be [root, c] but was #{d_from_db.ancestor_ids.inspect}"
    end
  end

  def test_stale_move_preserves_sibling
    AncestryTestDatabase.with_model do |model|
      # Tree: root -> a -> b, root -> a -> c
      root = model.create!
      a = model.create!(parent: root)
      b = model.create!(parent: a)
      c = model.create!(parent: a)

      # Move a to root
      a.update!(parent: nil)

      # Move b (stale) to root — c should still be under a
      b.update!(parent: nil)

      c_from_db = model.find(c.id)
      assert_equal [a.id], c_from_db.ancestor_ids,
        "c should still be under a, but was #{c_from_db.ancestor_ids.inspect}"
    end
  end
end
