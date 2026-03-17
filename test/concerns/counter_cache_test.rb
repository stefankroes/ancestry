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

      # update + update_descendants + decrement old parent + increment new parent
      assert_queries(4, "move with counter cache") do
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
