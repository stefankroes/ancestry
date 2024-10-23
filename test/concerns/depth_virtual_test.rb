require_relative '../environment'

# These are only valid for postgres 
class DepthVirtualTest < ActiveSupport::TestCase
  def test_depth_caching
    return unless test_virtual_column?

    AncestryTestDatabase.with_model :depth => 3, :width => 3, :cache_depth => :virtual do |_model, roots|
      roots.each do |lvl0_node, lvl0_children|
        assert_equal 0, lvl0_node.depth
        lvl0_children.each do |lvl1_node, lvl1_children|
          assert_equal 1, lvl1_node.depth
          lvl1_children.each do |lvl2_node, _lvl2_children|
            assert_equal 2, lvl2_node.depth
          end
        end
      end
    end
  end

  def test_depth_caching_after_subtree_movement
    return unless test_virtual_column?

    AncestryTestDatabase.with_model :depth => 6, :width => 1, :cache_depth => :virtual do |model, _roots|
      node = model.at_depth(3).first
      node.update(:parent => model.roots.first)
      assert_equal(1, node.depth)
      node.children.each do |child|
        assert_equal(2, child.depth)
        child.children.each do |gchild|
          assert_equal(3, gchild.depth)
        end
      end
    end
  end

  def test_depth_scopes
    return unless test_virtual_column?

    AncestryTestDatabase.with_model :depth => 4, :width => 2, :cache_depth => true do |model, _roots|
      model.before_depth(2).all? { |node| assert node.depth < 2 }
      model.to_depth(2).all?     { |node| assert node.depth <= 2 }
      model.at_depth(2).all?     { |node| assert node.depth == 2 }
      model.from_depth(2).all?   { |node| assert node.depth >= 2 }
      model.after_depth(2).all?  { |node| assert node.depth > 2 }
    end
  end

  def test_depth_scopes_without_depth_cache
    return unless test_virtual_column?

    AncestryTestDatabase.with_model :depth => 4, :width => 2 do |model, _roots|
      model.before_depth(2).all? { |node| assert node.depth < 2 }
      model.to_depth(2).all?     { |node| assert node.depth <= 2 }
      model.at_depth(2).all?     { |node| assert node.depth == 2 }
      model.from_depth(2).all?   { |node| assert node.depth >= 2 }
      model.after_depth(2).all?  { |node| assert node.depth > 2 }
    end
  end

  def test_exception_when_rebuilding_depth_cache_for_model_without_depth_caching
    return unless test_virtual_column?

    AncestryTestDatabase.with_model do |model|
      assert_raise Ancestry::AncestryException do
        model.rebuild_depth_cache!
      end
    end
  end

  def test_exception_on_unknown_depth_column
    return unless test_virtual_column?

    AncestryTestDatabase.with_model :cache_depth => true do |model|
      assert_raise Ancestry::AncestryException do
        model.create!.subtree(:this_is_not_a_valid_depth_option => 42)
      end
    end
  end

  # we are already testing generate and parse against static values
  # this assumes those are methods are tested and working
  def test_ancestry_depth_change
    return unless test_virtual_column?

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

  def test_virtual_column?
    AncestryTestDatabase.postgres? && ActiveRecord.version.to_s >= "7.0"
  end
end
