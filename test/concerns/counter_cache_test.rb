require_relative '../environment'

class CounterCacheTest < ActiveSupport::TestCase
  def test_counter_cache_when_creating
    AncestryTestDatabase.with_model :depth => 2, :width => 2, :counter_cache => true do |model, roots|
      roots.each do |lvl0_node, lvl0_children|
        assert_equal 2, lvl0_node.reload.children_count
      end
    end
  end

  def test_counter_cache_when_destroying
    AncestryTestDatabase.with_model :depth => 2, :width => 2, :counter_cache => true do |model, roots|
      parent = roots.first.first
      child = parent.children.first
      assert_difference 'parent.reload.children_count', -1 do
        child.destroy
      end
    end
  end

  def test_counter_cache_when_updating_parent
    AncestryTestDatabase.with_model :depth => 2, :width => 2, :counter_cache => true do |model, roots|
      parent1 = roots.first.first
      parent2 = roots.last.first
      child = parent1.children.first

      assert_difference 'parent1.reload.children_count', -1 do
        assert_difference 'parent2.reload.children_count', 1 do
          child.update_attributes parent: parent2
        end
      end
    end
  end

  def test_counter_cache_when_updating_parent_and_previous_is_nil
    AncestryTestDatabase.with_model :depth => 2, :width => 2, :counter_cache => true do |model, roots|
      child = roots.first.first
      parent = roots.last.first

      assert_difference 'parent.reload.children_count', 1 do
        child.update_attributes parent: parent
      end
    end
  end

  def test_counter_cache_when_updating_parent_and_current_is_nil
    AncestryTestDatabase.with_model :depth => 2, :width => 2, :counter_cache => true do |model, roots|
      parent = roots.first.first
      child = parent.children.first

      assert_difference 'parent.reload.children_count', -1 do
        child.update_attributes parent: nil
      end
    end
  end

  def test_custom_counter_cache_column
    AncestryTestDatabase.with_model :depth => 2, :width => 2, :counter_cache => :nodes_count do |model, roots|
      roots.each do |lvl0_node, lvl0_children|
        assert_equal 2, lvl0_node.reload.nodes_count
      end
    end
  end
end
