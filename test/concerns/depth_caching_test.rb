require_relative '../environment'

class DepthCachingTest < ActiveSupport::TestCase
  def test_depth_caching
    AncestryTestDatabase.with_model :depth => 3, :width => 3, :cache_depth => :depth_cache do |_model, roots|
      roots.each do |lvl0_node, lvl0_children|
        assert_equal 0, lvl0_node.depth_cache
        lvl0_children.each do |lvl1_node, lvl1_children|
          assert_equal 1, lvl1_node.depth_cache
          lvl1_children.each do |lvl2_node, _lvl2_children|
            assert_equal 2, lvl2_node.depth_cache
          end
        end
      end
    end
  end

  def test_depth_caching_after_subtree_movement
    AncestryTestDatabase.with_model :depth => 6, :width => 1, :cache_depth => :depth_cache do |model, _roots|
      node = model.at_depth(3).first
      node.update(:parent => model.roots.first)
      assert_equal(1, node.depth_cache)
      node.descendants.each do |descendant|
        assert_equal(descendant.depth, descendant.depth_cache)
      end
    end
  end

  def test_depth_scopes
    AncestryTestDatabase.with_model :depth => 4, :width => 2, :cache_depth => true do |model, _roots|
      model.before_depth(2).all? { |node| assert node.depth < 2 }
      model.to_depth(2).all?     { |node| assert node.depth <= 2 }
      model.at_depth(2).all?     { |node| assert node.depth == 2 }
      model.from_depth(2).all?   { |node| assert node.depth >= 2 }
      model.after_depth(2).all?  { |node| assert node.depth > 2 }
    end
  end

  def test_depth_scopes_without_depth_cache
    AncestryTestDatabase.with_model :depth => 4, :width => 2 do |model, _roots|
      model.before_depth(2).all? { |node| assert node.depth < 2 }
      model.to_depth(2).all?     { |node| assert node.depth <= 2 }
      model.at_depth(2).all?     { |node| assert node.depth == 2 }
      model.from_depth(2).all?   { |node| assert node.depth >= 2 }
      model.after_depth(2).all?  { |node| assert node.depth > 2 }
    end
  end

  def test_rebuild_depth_cache
    AncestryTestDatabase.with_model :depth => 3, :width => 3, :cache_depth => :depth_cache do |model, _roots|
      model.update_all(:depth_cache => nil)

      # Assert cache was emptied correctly
      model.all.each do |test_node|
        assert_nil test_node.depth_cache
      end

      # Rebuild cache
      model.rebuild_depth_cache!

      # Assert cache was rebuild correctly
      model.all.each do |test_node|
        assert_equal test_node.depth, test_node.depth_cache
      end
    end
  end

  def test_rebuild_depth_cache_with_sql
    AncestryTestDatabase.with_model :depth => 3, :width => 3, :cache_depth => :depth_cache do |model, _roots|
      model.update_all(:depth_cache => nil)

      # Assert cache was emptied correctly
      model.all.each do |test_node|
        assert_nil test_node.depth_cache
      end

      # Rebuild cache
      # require "byebug"
      # byebug
      model.rebuild_depth_cache_sql!

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

  # we are already testing generate and parse against static values
  # this assumes those are methods are tested and working
  def test_ancestry_depth_change
    AncestryTestDatabase.with_model do |model|
      {
        [[], [1]]        => +1,
        [[1], []]        => -1,
        [[1], [2]]       =>  0,
        [[1], [1, 2, 3]] => +2,
        [[1, 2, 3], [1]] => -2
      }.each do |(before, after), diff|
        a_before = model.generate_ancestry(before)
        a_after = model.generate_ancestry(after)
        assert_equal(diff, model.ancestry_depth_change(a_before, a_after))
      end
    end
  end
end
