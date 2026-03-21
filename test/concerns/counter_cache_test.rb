# frozen_string_literal: true

require_relative '../environment'

class CounterCacheTest < ActiveSupport::TestCase
  def test_counter_cache_when_creating
    AncestryTestDatabase.with_model :depth => 2, :width => 2, :counter_cache => true do |_model, roots|
      roots.each do |lvl0_node, _lvl0_children|
        assert_equal 2, lvl0_node.reload.children_count
      end
    end
  end

  def test_counter_cache_when_destroying
    AncestryTestDatabase.with_model :depth => 2, :width => 2, :counter_cache => true do |_model, roots|
      parent = roots.first.first
      child = parent.children.first

      # check_descendants + delete + decrement parent
      assert_queries(3, "destroy leaf with counter cache") do
        child.destroy
      end

      assert_equal 1, parent.reload.children_count
    end
  end

  def test_counter_cache_when_reduplicate_destroying
    AncestryTestDatabase.with_model :depth => 2, :width => 2, :counter_cache => true do |_model, roots|
      parent = roots.first.first
      child = parent.children.first
      child2 = child.class.find(child.id)

      assert_difference 'parent.reload.children_count', -1 do
        child.destroy
        child2.destroy
      end
    end
  end

  def test_counter_cache_when_updating_parent
    AncestryTestDatabase.with_model :depth => 2, :width => 2, :counter_cache => true do |_model, roots|
      parent1 = roots.first.first
      parent2 = roots.last.first
      child = parent1.children.first

      # refresh_ancestry + update + update_descendants + decrement old parent + increment new parent
      assert_queries(5, "move with counter cache") do
        child.update parent: parent2
      end

      assert_equal 1, parent1.reload.children_count
      assert_equal 3, parent2.reload.children_count
    end
  end

  def test_counter_cache_when_updating_parent_and_previous_is_nil
    AncestryTestDatabase.with_model :depth => 2, :width => 2, :counter_cache => true do |_model, roots|
      child = roots.first.first
      parent = roots.last.first

      assert_difference 'parent.reload.children_count', 1 do
        child.update parent: parent
      end
    end
  end

  def test_counter_cache_when_updating_parent_and_current_is_nil
    AncestryTestDatabase.with_model :depth => 2, :width => 2, :counter_cache => true do |_model, roots|
      parent = roots.first.first
      child = parent.children.first

      assert_difference 'parent.reload.children_count', -1 do
        child.update parent: nil
      end
    end
  end

  def test_custom_counter_cache_column
    AncestryTestDatabase.with_model :depth => 2, :width => 2, :counter_cache => :nodes_count do |_model, roots|
      roots.each do |lvl0_node, _lvl0_children|
        assert_equal 2, lvl0_node.reload.nodes_count
      end
    end
  end

  def test_counter_cache_when_updating_record
    AncestryTestDatabase.with_model :depth => 2, :width => 2, :counter_cache => true, :extra_columns => {:name => :string} do |_model, roots|
      parent = roots.first.first
      child = parent.children.first

      # non-ancestry update: just the UPDATE, no ancestry callbacks
      assert_queries(1, "non-ancestry update") do
        child.update :name => "name2"
      end

      assert_equal 2, parent.reload.children_count
    end
  end

  def test_rebuild_counter_cache_returns_zero_when_correct
    AncestryTestDatabase.with_model :depth => 2, :width => 2, :counter_cache => true do |model, _roots|
      assert_equal 0, model.rebuild_counter_cache!(verbose: true)
    end
  end

  def test_counter_cache_on_destroy_with_orphan_destroy
    AncestryTestDatabase.with_model :depth => 3, :width => 2, :counter_cache => true do |_model, roots|
      root = roots.first.first
      child1 = root.children.first
      assert_equal 2, root.reload.children_count
      assert_equal 2, child1.reload.children_count

      # Destroying child1 with default orphan_strategy :destroy:
      # - destroys gc1, gc2
      # - decrements root's counter by 1
      child1.destroy

      assert_equal 1, root.reload.children_count,
        "root's counter should decrement by 1 after destroying child"
    end
  end

  def test_counter_cache_on_destroy_with_orphan_rootify
    AncestryTestDatabase.with_model :depth => 3, :width => 2, :counter_cache => true,
                                    :orphan_strategy => :rootify do |_model, roots|
      root = roots.first.first
      child1 = root.children.order(:id).first
      assert_equal 2, root.reload.children_count
      assert_equal 2, child1.reload.children_count

      # Destroying child1 with rootify:
      # - grandchildren become roots
      # - root loses child1
      child1.destroy

      assert_equal 1, root.reload.children_count,
        "root's counter should decrement after child destroyed"
    end
  end

  # orphan_strategy :adopt moves children inside without_ancestry_callbacks.
  # update_parent_counter_cache fires anyway (no ancestry_callbacks_disabled? guard),
  # so counters are correct. This is the desired behavior — the guard asymmetry
  # between increase/update (no guard) and decrease (guarded) is intentional.
  def test_counter_cache_on_destroy_with_orphan_adopt
    AncestryTestDatabase.with_model :depth => 3, :width => 2, :counter_cache => true,
                                    :orphan_strategy => :adopt do |model, roots|
      root = roots.first.first
      child1 = root.children.order(:id).first
      gc1, gc2 = child1.children.order(:id).to_a
      assert_equal 2, root.reload.children_count
      assert_equal 2, child1.reload.children_count

      # Destroying child1 with adopt:
      # - gc1 and gc2 are adopted by root (child1's parent)
      # - root loses child1 but gains gc1 and gc2
      child1.destroy

      # Verify the tree structure is correct
      assert_equal root.id, gc1.reload.parent_id, "gc1 should be adopted by root"
      assert_equal root.id, gc2.reload.parent_id, "gc2 should be adopted by root"
      assert_nil model.find_by(id: child1.id), "child1 should be destroyed"

      # Counter should reflect: lost child1 (-1), gained gc1 and gc2 (+2) = net +1
      assert_equal 3, root.reload.children_count,
        "root's counter should be 3 (child2 + adopted gc1 + gc2)"
    end
  end

  def test_counter_cache_on_destroy_subtree
    AncestryTestDatabase.with_model :depth => 3, :width => 2, :counter_cache => true do |_model, roots|
      root = roots.first.first
      assert_equal 2, root.reload.children_count

      root.destroy

      # Other roots should be unaffected
      other_root = roots.last.first
      assert_equal 2, other_root.reload.children_count
    end
  end

  # Bug #3: Move-then-destroy with stale object causes children_count = -1.
  # Request 1 loads child (parent_id = P in RAM). Request 2 moves child to Q.
  # Request 1 destroys stale child — decrements P again (already decremented by move).
  # P ends up at -1.
  # Known bug: cross-request stale object causes -1 counter (#521)
  # skip until we have a fix that doesn't regress write performance
  def skip_test_counter_cache_move_then_destroy_stale_object
    AncestryTestDatabase.with_model :counter_cache => true do |model, _roots|
      p1 = model.create!
      p2 = model.create!
      child = model.create!(parent: p1)

      assert_equal 1, p1.reload.children_count
      assert_equal 0, p2.reload.children_count

      # Simulate request 1: loads child (parent_id = p1 in RAM)
      stale_child = model.find(child.id)

      # Simulate request 2: moves child to p2
      child.update!(parent: p2)

      assert_equal 0, p1.reload.children_count
      assert_equal 1, p2.reload.children_count

      # Simulate request 1: destroys stale child (still thinks parent = p1)
      stale_child.destroy

      assert_equal 0, p1.reload.children_count, "p1 should be 0, not -1 (double decrement)"
      assert_equal 0, p2.reload.children_count, "p2 should be 0 (child destroyed)"
    end
  end

  # --- Duplicate destroy edge cases ---
  # Rails wraps destroy in a transaction. When DELETE affects 0 rows, Rails
  # rolls back so decrement_counter is undone. On Rails < 6.1, the
  # @_trigger_destroy_callback guard in decrease_parent_counter_cache is
  # needed to prevent same-object double-decrement (can be removed when
  # minimum Rails is 6.1+).
  def test_counter_cache_same_object_destroy_twice
    AncestryTestDatabase.with_model :depth => 2, :width => 2, :counter_cache => true do |_model, roots|
      parent = roots.first.first
      child = parent.children.first

      assert_equal 2, parent.reload.children_count
      child.destroy
      assert_equal 1, parent.reload.children_count
      child.destroy
      if ActiveRecord::VERSION::MAJOR > 6 || (ActiveRecord::VERSION::MAJOR == 6 && ActiveRecord::VERSION::MINOR >= 1)
        assert_equal 1, parent.reload.children_count,
          "same object destroyed twice should not double-decrement"
      else
        assert_equal 0, parent.reload.children_count,
          "Rails 6.0: same object destroy fires callbacks twice"
      end
    end
  end

  # Two Ruby objects for the same DB row — the second DELETE affects 0 rows,
  # Rails rolls back the transaction, so decrement_counter is undone
  def test_counter_cache_two_objects_destroy_same_record
    AncestryTestDatabase.with_model :depth => 2, :width => 2, :counter_cache => true do |model, roots|
      parent = roots.first.first
      child1 = parent.children.first
      child2 = model.find(child1.id)

      assert_equal 2, parent.reload.children_count
      child1.destroy
      assert_equal 1, parent.reload.children_count
      child2.destroy
      assert_equal 1, parent.reload.children_count,
        "different object for same record should not double-decrement"
    end
  end

  # Row deleted via delete_all (no callbacks), then stale object destroyed.
  # The DELETE affects 0 rows, Rails rolls back, counter unchanged.
  def test_counter_cache_destroy_already_deleted_row
    AncestryTestDatabase.with_model :depth => 2, :width => 2, :counter_cache => true do |model, roots|
      parent = roots.first.first
      child = parent.children.first
      stale = model.find(child.id)

      # delete_all bypasses callbacks — counter not decremented
      model.where(id: child.id).delete_all
      assert_equal 2, parent.reload.children_count

      # stale object tries to destroy — row already gone
      stale.destroy
      assert_equal 2, parent.reload.children_count,
        "destroying already-deleted row should not decrement counter"
    end
  end

  def test_setting_counter_cache
    AncestryTestDatabase.with_model :depth => 3, :width => 2, :counter_cache => true do |model, roots|
      # ensure they are successfully built
      roots.each do |lvl0_node, lvl0_children|
        assert_equal 2, lvl0_node.reload.children_count
        lvl0_children.each do |lvl1_node, lvl1_children|
          assert_equal 2, lvl1_node.reload.children_count
          lvl1_children.each do |lvl2_node, _lvl2_children|
            assert_equal 0, lvl2_node.reload.children_count
          end
        end
      end

      model.update_all(:children_count => 0)
      # ensure they are successfully broken
      roots.each do |lvl0_node, _lvl0_children|
        assert_equal 0, lvl0_node.reload.children_count
      end
      # depth 3, width 2: 2 roots × (1 + 2) = 6 nodes with children, all set to 0
      assert_equal 6, model.rebuild_counter_cache!(verbose: true)

      # ensure they are successfully built
      roots.each do |lvl0_node, lvl0_children|
        assert_equal 2, lvl0_node.reload.children_count
        lvl0_children.each do |lvl1_node, lvl1_children|
          assert_equal 2, lvl1_node.reload.children_count
          lvl1_children.each do |lvl2_node, _lvl2_children|
            assert_equal 0, lvl2_node.reload.children_count
          end
        end
      end
    end
  end
end
