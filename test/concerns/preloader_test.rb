# frozen_string_literal: true

require_relative '../environment'

class PreloaderTest < ActiveSupport::TestCase
  def test_preload_descendants_loads_all_descendants
    AncestryTestDatabase.with_model(depth: 3, width: 2) do |model, roots|
      # Get all root nodes
      root_nodes = roots.map(&:first)

      # Preload descendants
      Ancestry::Preloader.preload_descendants(root_nodes)

      # Verify each root has correct preloaded descendants
      root_nodes.each do |root|
        expected = root.descendants.to_a.sort_by(&:id)
        actual = root.preloaded_descendants.sort_by(&:id)
        assert_equal expected, actual, "Preloaded descendants should match actual descendants"
      end
    end
  end

  def test_preload_descendants_avoids_n_plus_one
    AncestryTestDatabase.with_model(depth: 3, width: 2) do |model, roots|
      root_nodes = roots.map(&:first)

      # Preload descendants (this should be the only query)
      Ancestry::Preloader.preload_descendants(root_nodes)

      # Count queries when accessing preloaded descendants
      query_count = 0
      counter = ->(_name, _start, _finish, _id, payload) {
        query_count += 1 if payload[:sql] =~ /SELECT.*FROM.*test_nodes/i
      }

      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        root_nodes.each do |root|
          root.preloaded_descendants
        end
      end

      assert_equal 0, query_count, "Accessing preloaded_descendants should not issue queries"
    end
  end

  def test_preload_descendants_with_depth_limit
    AncestryTestDatabase.with_model(depth: 4, width: 2) do |model, roots|
      root = roots.first.first

      # Preload with depth limit of 2
      Ancestry::Preloader.preload_descendants([root], depth: 2)

      # Should only include descendants up to depth 2
      preloaded = root.preloaded_descendants
      max_depth = preloaded.map(&:depth).max || 0

      assert max_depth <= root.depth + 2, "Preloaded descendants should respect depth limit"
      assert preloaded.all? { |d| d.depth <= root.depth + 2 }, "All descendants should be within depth limit"
    end
  end

  def test_preload_descendants_with_empty_array
    AncestryTestDatabase.with_model do |model|
      result = Ancestry::Preloader.preload_descendants([])
      assert_equal [], result
    end
  end

  def test_preload_descendants_with_single_record
    AncestryTestDatabase.with_model(depth: 2, width: 2) do |model, roots|
      root = roots.first.first

      Ancestry::Preloader.preload_descendants([root])

      expected = root.descendants.to_a.sort_by(&:id)
      actual = root.preloaded_descendants.sort_by(&:id)
      assert_equal expected, actual
    end
  end

  def test_preload_descendants_with_nested_records
    AncestryTestDatabase.with_model(depth: 3, width: 2) do |model, roots|
      root = roots.first.first
      child = root.children.first

      # Preload for both parent and child
      Ancestry::Preloader.preload_descendants([root, child])

      # Root should have all descendants
      root_descendants = root.preloaded_descendants.sort_by(&:id)
      expected_root_descendants = root.descendants.to_a.sort_by(&:id)
      assert_equal expected_root_descendants, root_descendants

      # Child should have its own descendants (subset of root's)
      child_descendants = child.preloaded_descendants.sort_by(&:id)
      expected_child_descendants = child.descendants.to_a.sort_by(&:id)
      assert_equal expected_child_descendants, child_descendants
    end
  end

  def test_preload_descendants_with_leaf_node
    AncestryTestDatabase.with_model(depth: 2, width: 2) do |model, roots|
      # Get a leaf node (no children)
      leaf = model.all.select(&:is_childless?).first

      Ancestry::Preloader.preload_descendants([leaf])

      assert_equal [], leaf.preloaded_descendants
    end
  end

  def test_preload_descendants_returns_records_for_chaining
    AncestryTestDatabase.with_model(depth: 2, width: 2) do |model, roots|
      root_nodes = roots.map(&:first)

      result = Ancestry::Preloader.preload_descendants(root_nodes)

      assert_equal root_nodes, result
    end
  end

  def test_preloaded_descendants_fallback_without_preload
    AncestryTestDatabase.with_model(depth: 2, width: 2) do |model, roots|
      root = roots.first.first

      # Without preloading, should still work (issues a query)
      result = root.preloaded_descendants

      assert_equal root.descendants.to_a.sort_by(&:id), result.sort_by(&:id)
    end
  end

  def test_preload_descendants_raises_for_unpersisted_record
    AncestryTestDatabase.with_model do |model|
      unpersisted = model.new

      error = assert_raises(Ancestry::AncestryException) do
        Ancestry::Preloader.preload_descendants([unpersisted])
      end

      assert_match(/unpersisted/, error.message)
    end
  end

  def test_preload_descendants_single_query_for_multiple_records
    AncestryTestDatabase.with_model(depth: 3, width: 3) do |model, roots|
      root_nodes = roots.map(&:first)

      query_count = 0
      counter = ->(_name, _start, _finish, _id, payload) {
        # Count SELECT queries on test_nodes table
        query_count += 1 if payload[:sql] =~ /SELECT.*FROM.*test_nodes/i
      }

      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        Ancestry::Preloader.preload_descendants(root_nodes)
      end

      # Should only issue 1 query for all descendants
      assert_equal 1, query_count, "Should load all descendants in a single query"
    end
  end
end
