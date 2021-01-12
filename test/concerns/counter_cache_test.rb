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
      assert_difference 'parent.reload.children_count', -1 do
        child.destroy
      end
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

      assert_difference 'parent1.reload.children_count', -1 do
        assert_difference 'parent2.reload.children_count', 1 do
          child.update parent: parent2
        end
      end
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

      assert_difference 'parent.reload.children_count', 0 do
        child.update :name => "name2"
      end
    end
  end
end
