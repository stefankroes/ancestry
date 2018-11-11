require_relative '../environment'

class TreeNavigationTest < ActiveSupport::TestCase
  def test_tree_navigation
    AncestryTestDatabase.with_model :depth => 3, :width => 3 do |model, roots|
      roots.each do |lvl0_node, lvl0_children|
        # Ancestors assertions
        assert_equal [], lvl0_node.ancestor_ids
        assert_equal [], lvl0_node.ancestors
        assert_equal [lvl0_node.id], lvl0_node.path_ids
        assert_equal [lvl0_node], lvl0_node.path
        assert_equal 0, lvl0_node.depth
        # Parent assertions
        assert_nil lvl0_node.parent_id
        assert_nil lvl0_node.parent
        refute lvl0_node.parent_id?
        # Root assertions
        assert_equal lvl0_node.id, lvl0_node.root_id
        assert_equal lvl0_node, lvl0_node.root
        assert lvl0_node.is_root?
        # Children assertions
        assert_equal lvl0_children.map(&:first).map(&:id), lvl0_node.child_ids
        assert_equal lvl0_children.map(&:first), lvl0_node.children
        assert lvl0_node.has_children?
        assert !lvl0_node.is_childless?
        # Siblings assertions
        assert_equal roots.map(&:first).map(&:id), lvl0_node.sibling_ids
        assert_equal roots.map(&:first), lvl0_node.siblings
        assert lvl0_node.has_siblings?
        assert !lvl0_node.is_only_child?
        # Descendants assertions
        descendants = model.all.find_all do |node|
          node.ancestor_ids.include? lvl0_node.id
        end
        assert_equal descendants.map(&:id), lvl0_node.descendant_ids
        assert_equal descendants, lvl0_node.descendants
        assert_equal [lvl0_node] + descendants, lvl0_node.subtree

        lvl0_children.each do |lvl1_node, lvl1_children|
          # Ancestors assertions
          assert_equal [lvl0_node.id], lvl1_node.ancestor_ids
          assert_equal [lvl0_node], lvl1_node.ancestors
          assert_equal [lvl0_node.id, lvl1_node.id], lvl1_node.path_ids
          assert_equal [lvl0_node, lvl1_node], lvl1_node.path
          assert_equal 1, lvl1_node.depth
          # Parent assertions
          assert_equal lvl0_node.id, lvl1_node.parent_id
          assert_equal lvl0_node, lvl1_node.parent
          assert lvl1_node.parent_id?
          # Root assertions
          assert_equal lvl0_node.id, lvl1_node.root_id
          assert_equal lvl0_node, lvl1_node.root
          assert !lvl1_node.is_root?
          # Children assertions
          assert_equal lvl1_children.map(&:first).map(&:id), lvl1_node.child_ids
          assert_equal lvl1_children.map(&:first), lvl1_node.children
          assert lvl1_node.has_children?
          assert !lvl1_node.is_childless?
          # Siblings assertions
          assert_equal lvl0_children.map(&:first).map(&:id), lvl1_node.sibling_ids
          assert_equal lvl0_children.map(&:first), lvl1_node.siblings
          assert lvl1_node.has_siblings?
          assert !lvl1_node.is_only_child?
          # Descendants assertions
          descendants = model.all.find_all do |node|
            node.ancestor_ids.include? lvl1_node.id
          end
          assert_equal descendants.map(&:id), lvl1_node.descendant_ids
          assert_equal descendants, lvl1_node.descendants
          assert_equal [lvl1_node] + descendants, lvl1_node.subtree

          lvl1_children.each do |lvl2_node, lvl2_children|
            # Ancestors assertions
            assert_equal [lvl0_node.id, lvl1_node.id], lvl2_node.ancestor_ids
            assert_equal [lvl0_node, lvl1_node], lvl2_node.ancestors
            assert_equal [lvl0_node.id, lvl1_node.id, lvl2_node.id], lvl2_node.path_ids
            assert_equal [lvl0_node, lvl1_node, lvl2_node], lvl2_node.path
            assert_equal 2, lvl2_node.depth
            # Parent assertions
            assert_equal lvl1_node.id, lvl2_node.parent_id
            assert_equal lvl1_node, lvl2_node.parent
            assert lvl2_node.parent_id?
            # Root assertions
            assert_equal lvl0_node.id, lvl2_node.root_id
            assert_equal lvl0_node, lvl2_node.root
            assert !lvl2_node.is_root?
            # Children assertions
            assert_equal [], lvl2_node.child_ids
            assert_equal [], lvl2_node.children
            assert !lvl2_node.has_children?
            assert lvl2_node.is_childless?
            # Siblings assertions
            assert_equal lvl1_children.map(&:first).map(&:id), lvl2_node.sibling_ids
            assert_equal lvl1_children.map(&:first), lvl2_node.siblings
            assert lvl2_node.has_siblings?
            assert !lvl2_node.is_only_child?
            # Descendants assertions
            descendants = model.all.find_all do |node|
              node.ancestor_ids.include? lvl2_node.id
            end
            assert_equal descendants.map(&:id), lvl2_node.descendant_ids
            assert_equal descendants, lvl2_node.descendants
            assert_equal [lvl2_node] + descendants, lvl2_node.subtree
          end
        end
      end
    end
  end
end
