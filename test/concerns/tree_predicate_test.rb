require_relative '../environment'

class TreePredicateTest < ActiveSupport::TestCase
  def test_tree_predicates
    AncestryTestDatabase.with_model :depth => 2, :width => 3 do |_model, roots|
      roots.each do |lvl0_node, lvl0_children|
        root, children = lvl0_node, lvl0_children.map(&:first)
        # Ancestors assertions
        assert children.map { |n| root.ancestor_of?(n) }.all?
        assert children.map { |n| !n.ancestor_of?(root) }.all?
        # Parent assertions
        assert children.map { |n| root.parent_of?(n) }.all?
        assert children.map { |n| !n.parent_of?(root) }.all?
        # Root assertions
        assert root.is_root?
        assert children.map { |n| !n.is_root? }.all?
        assert children.map { |n| root.root_of?(n) }.all?
        assert children.map { |n| !n.root_of?(root) }.all?
        # Children assertions
        assert root.has_children?
        assert !root.is_childless?
        assert children.map { |n| n.is_childless? }.all?
        assert children.map { |n| !root.child_of?(n) }.all?
        assert children.map { |n| n.child_of?(root) }.all?
        # Siblings assertions
        refute root.has_siblings?
        assert root.is_only_child?
        assert children.map { |n| !n.is_only_child? }.all?
        assert children.map { |n| !root.sibling_of?(n) }.all?
        assert children.permutation(2).map { |l, r| l.sibling_of?(r) }.all?
        # Descendants assertions
        assert children.map { |n| !root.descendant_of?(n) }.all?
        assert children.map { |n| n.descendant_of?(root) }.all?
      end
    end
  end
end
