require_relative '../environment'

class DepthCachingTest < ActiveSupport::TestCase
  def test_depth_caching
    AncestryTestDatabase.with_model :depth => 3, :width => 3, :cache_depth => true, :depth_cache_column => :depth_cache do |model, roots|
      roots.each do |lvl0_node, lvl0_children|
        assert_equal 0, lvl0_node.depth_cache
        lvl0_children.each do |lvl1_node, lvl1_children|
          assert_equal 1, lvl1_node.depth_cache
          lvl1_children.each do |lvl2_node, lvl2_children|
            assert_equal 2, lvl2_node.depth_cache
          end
        end
      end
    end
  end

  def test_depth_caching_after_subtree_movement
    AncestryTestDatabase.with_model :depth => 6, :width => 1, :cache_depth => true, :depth_cache_column => :depth_cache do |model, roots|
      node = model.at_depth(3).first
      node.update_attributes(:parent => model.roots.first)
      assert_equal(1, node.depth_cache)
      node.descendants.each do |descendant|
        assert_equal(descendant.depth, descendant.depth_cache)
      end
    end
  end

  def test_depth_scopes
    AncestryTestDatabase.with_model :depth => 4, :width => 2, :cache_depth => true do |model, roots|
      model.before_depth(2).all? { |node| assert node.depth < 2 }
      model.to_depth(2).all?     { |node| assert node.depth <= 2 }
      model.at_depth(2).all?     { |node| assert node.depth == 2 }
      model.from_depth(2).all?   { |node| assert node.depth >= 2 }
      model.after_depth(2).all?  { |node| assert node.depth > 2 }
    end
  end

  def test_depth_scopes_unavailable
    AncestryTestDatabase.with_model do |model|
      assert_raise Ancestry::AncestryException do
        model.before_depth(1)
      end
      assert_raise Ancestry::AncestryException do
        model.to_depth(1)
      end
      assert_raise Ancestry::AncestryException do
        model.at_depth(1)
      end
      assert_raise Ancestry::AncestryException do
        model.from_depth(1)
      end
      assert_raise Ancestry::AncestryException do
        model.after_depth(1)
      end
    end
  end

  def test_rebuild_depth_cache
    AncestryTestDatabase.with_model :depth => 3, :width => 3, :cache_depth => true, :depth_cache_column => :depth_cache do |model, roots|
      model.connection.execute("update test_nodes set depth_cache = null;")

      # Assert cache was emptied correctly
      model.all.each do |test_node|
        assert_equal nil, test_node.depth_cache
      end

      # Rebuild cache
      model.rebuild_depth_cache!

      # Assert cache was rebuild correctly
      model.all.each do |test_node|
        assert_equal test_node.depth, test_node.depth_cache
      end
    end
  end

  def test_exception_when_rebuilding_depth_cache_for_model_without_depth_caching
    AncestryTestDatabase.with_model do |model|
      assert_raise Ancestry::AncestryException do
        model.rebuild_depth_cache!
      end
    end
  end

  def test_exception_on_unknown_depth_column
    AncestryTestDatabase.with_model :cache_depth => true do |model|
      assert_raise Ancestry::AncestryException do
        model.create!.subtree(:this_is_not_a_valid_depth_option => 42)
      end
    end
  end
end