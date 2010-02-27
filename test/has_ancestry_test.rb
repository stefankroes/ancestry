require File.dirname(__FILE__) + '/test_helper.rb'

# Setup the required models for all test cases

class TestNode < ActiveRecord::Base
  has_ancestry :cache_depth => true, :depth_cache_column => :depth_cache
end

class AlternativeTestNode < ActiveRecord::Base
  has_ancestry :ancestry_column => :alternative_ancestry, :orphan_strategy => :rootify
end

class ActsAsTreeTestNode < ActiveRecord::Base
  acts_as_tree
end

class ParentIdTestNode < ActiveRecord::Base
end

class TestNodeSub1 < TestNode
end

class TestNodeSub2 < TestNode
end

class ActsAsTreeTest < ActiveSupport::TestCase
  load_schema
  
  def setup_test_nodes model, level, quantity
    model.delete_all
    create_test_nodes model, nil, level, quantity
  end

  def create_test_nodes model, parent, level, quantity
    unless level == 0
      (1..quantity).map do |i|
        node = model.create!(:parent => parent)
        [node, create_test_nodes(model, node, level - 1, quantity)]
      end
    else; []; end
  end

  def test_default_ancestry_column
    assert_equal :ancestry, TestNode.ancestry_column
  end
  
  def test_non_default_ancestry_column
    assert_equal :alternative_ancestry, AlternativeTestNode.ancestry_column
  end
  
  def test_setting_ancestry_column
    TestNode.ancestry_column = :ancestors
    assert_equal :ancestors, TestNode.ancestry_column
    TestNode.ancestry_column = :ancestry
    assert_equal :ancestry, TestNode.ancestry_column
  end
  
  def test_default_orphan_strategy
    assert_equal :destroy, TestNode.orphan_strategy
  end
  
  def test_non_default_orphan_strategy
    assert_equal :rootify, AlternativeTestNode.orphan_strategy
  end
  
  def test_setting_orphan_strategy
    TestNode.orphan_strategy = :rootify
    assert_equal :rootify, TestNode.orphan_strategy
    TestNode.orphan_strategy = :destroy
    assert_equal :destroy, TestNode.orphan_strategy
  end

  def test_setting_invalid_orphan_strategy
    assert_raise Ancestry::AncestryException do
      TestNode.orphan_strategy = :non_existent_orphan_strategy
    end
  end

  def test_setup_test_nodes
    [TestNode, AlternativeTestNode, ActsAsTreeTestNode].each do |model|
      roots = setup_test_nodes model, 3, 3
      assert_equal Array, roots.class
      assert_equal 3, roots.length
      roots.each do |node, children|
        assert_equal model, node.class
        assert_equal Array, children.class
        assert_equal 3, children.length
        children.each do |node, children|
          assert_equal model, node.class
          assert_equal Array, children.class
          assert_equal 3, children.length
          children.each do |node, children|
            assert_equal model, node.class
            assert_equal Array, children.class
            assert_equal 0, children.length
          end
        end
      end
    end
  end

  def test_tree_navigation
    roots = setup_test_nodes TestNode, 3, 3
    roots.each do |lvl0_node, lvl0_children|
      # Ancestors assertions
      assert_equal [], lvl0_node.ancestor_ids
      assert_equal [], lvl0_node.ancestors
      assert_equal [lvl0_node.id], lvl0_node.path_ids
      assert_equal [lvl0_node], lvl0_node.path
      assert_equal 0, lvl0_node.depth
      # Parent assertions
      assert_equal nil, lvl0_node.parent_id
      assert_equal nil, lvl0_node.parent
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
      descendants = TestNode.all.find_all do |node|
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
        descendants = TestNode.all.find_all do |node|
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
          descendants = TestNode.all.find_all do |node|
            node.ancestor_ids.include? lvl2_node.id
          end
          assert_equal descendants.map(&:id), lvl2_node.descendant_ids
          assert_equal descendants, lvl2_node.descendants
          assert_equal [lvl2_node] + descendants, lvl2_node.subtree
        end
      end
    end
  end
  
  def test_named_scopes
    roots = setup_test_nodes TestNode, 3, 3

    # Roots assertion
    assert_equal roots.map(&:first), TestNode.roots.all
    
    TestNode.all.each do |test_node|
      # Assertions for ancestors_of named scope
      assert_equal test_node.ancestors, TestNode.ancestors_of(test_node)
      assert_equal test_node.ancestors, TestNode.ancestors_of(test_node.id)
      # Assertions for children_of named scope
      assert_equal test_node.children, TestNode.children_of(test_node)
      assert_equal test_node.children, TestNode.children_of(test_node.id)
      # Assertions for descendants_of named scope
      assert_equal test_node.descendants, TestNode.descendants_of(test_node)
      assert_equal test_node.descendants, TestNode.descendants_of(test_node.id)
      # Assertions for subtree_of named scope
      assert_equal test_node.subtree, TestNode.subtree_of(test_node)
      assert_equal test_node.subtree, TestNode.subtree_of(test_node.id)
      # Assertions for siblings_of named scope
      assert_equal test_node.siblings, TestNode.siblings_of(test_node)
      assert_equal test_node.siblings, TestNode.siblings_of(test_node.id)
    end
  end
  
  def test_ancestroy_column_validation
    node = TestNode.create
    ['3', '10/2', '1/4/30', nil].each do |value|
      node.write_attribute TestNode.ancestry_column, value
      node.valid?; assert !node.errors.invalid?(TestNode.ancestry_column)
    end
    ['1/3/', '/2/3', 'a', 'a/b', '-34', '/54'].each do |value|
      node.write_attribute TestNode.ancestry_column, value
      node.valid?; assert node.errors.invalid?(TestNode.ancestry_column)
    end
  end
  
  def test_descendants_move_with_node
    root1, root2, root3 = setup_test_nodes(TestNode, 3, 3).map(&:first)
     assert_no_difference 'root1.descendants.size' do
      assert_difference 'root2.descendants.size', root1.subtree.size do
        root1.parent = root2
        root1.save!
      end
    end
    assert_no_difference 'root2.descendants.size' do
      assert_difference 'root3.descendants.size', root2.subtree.size do
        root2.parent = root3
        root2.save!
      end
    end
    assert_no_difference 'root1.descendants.size' do
      assert_difference 'root2.descendants.size', -root1.subtree.size do
        assert_difference 'root3.descendants.size', -root1.subtree.size do
          root1.parent = nil
          root1.save!
        end
      end
    end
  end
  
  def test_orphan_rootify_strategy
    TestNode.orphan_strategy = :rootify
    root = setup_test_nodes(TestNode, 3, 3).first.first
    children = root.children.all
    root.destroy
    children.each do |child|
      child.reload
      assert child.is_root?
      assert_equal 3, child.children.size
    end
  end

  def test_orphan_destroy_strategy
    TestNode.orphan_strategy = :destroy
    root = setup_test_nodes(TestNode, 3, 3).first.first
    assert_difference 'TestNode.count', -root.subtree.size do
      root.destroy
    end
    node = TestNode.roots.first.children.first
    assert_difference 'TestNode.count', -node.subtree.size do
      node.destroy
    end
  end

  def test_orphan_restrict_strategy
    TestNode.orphan_strategy = :restrict
    setup_test_nodes(TestNode, 3, 3)
    root = TestNode.roots.first
    assert_raise Ancestry::AncestryException do
      root.destroy
    end
    assert_nothing_raised Ancestry::AncestryException do
      root.children.first.children.first.destroy
    end
    
  end
  
  def test_integrity_checking
    # Check that there are no errors on a valid data set
    setup_test_nodes(TestNode, 3, 3)
    assert_nothing_raised do
      TestNode.check_ancestry_integrity!
    end

    # Check detection of invalid format for ancestry column
    setup_test_nodes(TestNode, 3, 3).first.first.update_attribute TestNode.ancestry_column, 'invalid_ancestry'
    assert_raise Ancestry::AncestryIntegrityException do
      TestNode.check_ancestry_integrity!
    end
    
    # Check detection of non-existent ancestor
    setup_test_nodes(TestNode, 3, 3).first.first.update_attribute TestNode.ancestry_column, 35
    assert_raise Ancestry::AncestryIntegrityException do
      TestNode.check_ancestry_integrity!
    end

    # Check detection of cyclic ancestry
    node = setup_test_nodes(TestNode, 3, 3).first.first
    node.update_attribute TestNode.ancestry_column, node.id
    assert_raise Ancestry::AncestryIntegrityException do
      TestNode.check_ancestry_integrity!
    end

    # Check detection of conflicting parent id
    TestNode.destroy_all
    TestNode.create!(TestNode.ancestry_column => TestNode.create!(TestNode.ancestry_column => TestNode.create!(TestNode.ancestry_column => nil).id).id)
    assert_raise Ancestry::AncestryIntegrityException do
      TestNode.check_ancestry_integrity!
    end
  end

  def assert_integrity_restoration
    assert_raise Ancestry::AncestryIntegrityException do
      TestNode.check_ancestry_integrity!
    end
    TestNode.restore_ancestry_integrity!
    assert_nothing_raised do
      TestNode.check_ancestry_integrity!
    end
  end    

  def test_integrity_restoration
    # Check that integrity is restored for invalid format for ancestry column
    setup_test_nodes(TestNode, 3, 3).first.first.update_attribute TestNode.ancestry_column, 'invalid_ancestry'
    assert_integrity_restoration
    
    # Check that integrity is restored for non-existent ancestor
    setup_test_nodes(TestNode, 3, 3).first.first.update_attribute TestNode.ancestry_column, 35
    assert_integrity_restoration

    # Check that integrity is restored for cyclic ancestry
    node = setup_test_nodes(TestNode, 3, 3).first.first
    node.update_attribute TestNode.ancestry_column, node.id
    assert_integrity_restoration

    # Check that integrity is restored for conflicting parent id
    TestNode.destroy_all
    TestNode.create!(TestNode.ancestry_column => TestNode.create!(TestNode.ancestry_column => TestNode.create!(TestNode.ancestry_column => nil).id).id)
    assert_integrity_restoration
  end
  
  def test_arrangement
    id_sorter = Proc.new do |a, b|; a.id <=> b.id; end
    setup_test_nodes(TestNode, 3, 3)
    arranged_nodes = TestNode.arrange
    assert_equal 3, arranged_nodes.size
    arranged_nodes.each do |node, children|
      assert_equal node.children.sort(&id_sorter), children.keys.sort(&id_sorter)
      children.each do |node, children|
        assert_equal node.children.sort(&id_sorter), children.keys.sort(&id_sorter)
        children.each do |node, children|
          assert_equal 0, children.size
        end
      end
    end
  end
  
  def test_node_creation_though_scope
    node = TestNode.create!
    child = node.children.create
    assert_equal node, child.parent 

    other_child = child.siblings.create!
    assert_equal node, other_child.parent

    grandchild = TestNode.children_of(child).new
    grandchild.save
    assert_equal child, grandchild.parent

    other_grandchild = TestNode.siblings_of(grandchild).new
    other_grandchild.save!
    assert_equal child, other_grandchild.parent
  end
  
  def test_validate_ancestry_exclude_self
    parent = TestNode.create!
    child = parent.children.create!
    assert_raise ActiveRecord::RecordInvalid do
      parent.update_attributes! :parent => child
    end
  end
  
  def test_depth_caching
    roots = setup_test_nodes TestNode, 3, 3
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
  
  def test_depth_scopes
    setup_test_nodes TestNode, 4, 4
    TestNode.before_depth(2).all? { |node| assert node.depth < 2 }
    TestNode.to_depth(2).all?     { |node| assert node.depth <= 2 }
    TestNode.at_depth(2).all?     { |node| assert node.depth == 2 }
    TestNode.from_depth(2).all?   { |node| assert node.depth >= 2 }
    TestNode.after_depth(2).all?  { |node| assert node.depth > 2 }
  end
  
  def test_depth_scopes_unavailable
    assert_raise Ancestry::AncestryException do
      AlternativeTestNode.before_depth(1)
      AlternativeTestNode.to_depth(1)
      AlternativeTestNode.at_depth(1)
      AlternativeTestNode.from_depth(1)
      AlternativeTestNode.after_depth(1)
    end
  end
  
  def test_invalid_has_ancestry_options
    assert_raise Ancestry::AncestryException do
      Class.new(ActiveRecord::Base).has_ancestry :this_option_doesnt_exist => 42
    end
    assert_raise Ancestry::AncestryException do
      Class.new(ActiveRecord::Base).has_ancestry :not_a_hash
    end
  end
  
  def test_build_ancestry_from_parent_ids
    [ParentIdTestNode.create!].each do |parent|
      (Array.new(5) { ParentIdTestNode.create! :parent_id => parent.id }).each do |parent|
        (Array.new(5) { ParentIdTestNode.create! :parent_id => parent.id }).each do |parent|
          (Array.new(5) { ParentIdTestNode.create! :parent_id => parent.id })
        end
      end
    end
    
    # Assert all nodes where created
    assert_equal 156, ParentIdTestNode.count

    ParentIdTestNode.has_ancestry
    ParentIdTestNode.build_ancestry_from_parent_ids!

    # Assert ancestry integirty
    assert_nothing_raised do
      ParentIdTestNode.check_ancestry_integrity!
    end

    roots = ParentIdTestNode.roots.all
    # Assert single root node
    assert_equal 1, roots.size

    # Assert it has 5 children
    roots.each do |parent|
      assert 5, parent.children.count
      parent.children.each do |parent|
        assert 5, parent.children.count
        parent.children.each do |parent|
          assert 5, parent.children.count
          parent.children.each do |parent|
            assert 0, parent.children.count
          end
        end
      end
    end
  end
  
  def test_rebuild_depth_cache
    setup_test_nodes TestNode, 3, 3
    TestNode.connection.execute("update test_nodes set depth_cache = null;")
    
    # Assert cache was emptied correctly
    TestNode.all.each do |test_node|
      assert_equal nil, test_node.depth_cache
    end
    
    # Rebuild cache
    TestNode.rebuild_depth_cache!
    
    # Assert cache was rebuild correctly
    TestNode.all.each do |test_node|
      assert_equal test_node.depth, test_node.depth_cache
    end
  end
  
  def test_exception_when_rebuilding_depth_cache_for_model_without_depth_caching
    assert_raise Ancestry::AncestryException do
      AlternativeTestNode.rebuild_depth_cache!
    end
  end
  
  def test_descendants_with_depth_constraints
    setup_test_nodes TestNode, 4, 4

    assert_equal 4, TestNode.roots.first.descendants(:before_depth => 2).count
    assert_equal 20, TestNode.roots.first.descendants(:to_depth => 2).count
    assert_equal 16, TestNode.roots.first.descendants(:at_depth => 2).count
    assert_equal 80, TestNode.roots.first.descendants(:from_depth => 2).count
    assert_equal 64, TestNode.roots.first.descendants(:after_depth => 2).count
  end

  def test_subtree_with_depth_constraints
    setup_test_nodes TestNode, 4, 4

    assert_equal 5, TestNode.roots.first.subtree(:before_depth => 2).count
    assert_equal 21, TestNode.roots.first.subtree(:to_depth => 2).count
    assert_equal 16, TestNode.roots.first.subtree(:at_depth => 2).count
    assert_equal 80, TestNode.roots.first.subtree(:from_depth => 2).count
    assert_equal 64, TestNode.roots.first.subtree(:after_depth => 2).count
  end


  def test_ancestors_with_depth_constraints
    node1 = TestNode.create!
    node2 = node1.children.create!
    node3 = node2.children.create!
    node4 = node3.children.create!
    node5 = node4.children.create!
    leaf  = node5.children.create!

    assert_equal [node1, node2, node3],        leaf.ancestors(:before_depth => -2)
    assert_equal [node1, node2, node3, node4], leaf.ancestors(:to_depth => -2)
    assert_equal [node4],                      leaf.ancestors(:at_depth => -2)
    assert_equal [node4, node5],               leaf.ancestors(:from_depth => -2)
    assert_equal [node5],                      leaf.ancestors(:after_depth => -2)
  end

  def test_path_with_depth_constraints
    node1 = TestNode.create!
    node2 = node1.children.create!
    node3 = node2.children.create!
    node4 = node3.children.create!
    node5 = node4.children.create!
    leaf  = node5.children.create!

    assert_equal [node1, node2, node3],        leaf.path(:before_depth => -2)
    assert_equal [node1, node2, node3, node4], leaf.path(:to_depth => -2)
    assert_equal [node4],                      leaf.path(:at_depth => -2)
    assert_equal [node4, node5, leaf],         leaf.path(:from_depth => -2)
    assert_equal [node5, leaf],                leaf.path(:after_depth => -2)
  end
  
  def test_exception_on_unknown_depth_column
    assert_raise Ancestry::AncestryException do
      TestNode.create!.subtree(:this_is_not_a_valid_depth_option => 42)
    end
  end
  
  def test_sti_support
    node1 = TestNodeSub1.create!
    node2 = TestNodeSub2.create! :parent => node1
    node3 = TestNodeSub1.create! :parent => node2
    node4 = TestNodeSub2.create! :parent => node3
    node5 = TestNodeSub1.create! :parent => node4
    
    assert_equal [node2, node3, node4, node5], node1.descendants
    assert_equal [node1, node2, node3, node4, node5], node1.subtree
    assert_equal [node1, node2, node3, node4], node5.ancestors
    assert_equal [node1, node2, node3, node4, node5], node5.path
  end
  
  def test_arrange_order_option
    # In Ruby versions before 1.9 hashes aren't ordered so this doesn't make sense
    unless RUBY_VERSION =~ /^1\.8/
      roots = setup_test_nodes TestNode, 3, 3
      descending_nodes_lvl0 = TestNode.arrange :order => 'id desc'
      ascending_nodes_lvl0 = TestNode.arrange :order => 'id asc'

      descending_nodes_lvl0.keys.zip(ascending_nodes_lvl0.keys.reverse).each do |descending_node, ascending_node|
        assert_equal descending_node, ascending_node
        descending_nodes_lvl1 = descending_nodes_lvl0[descending_node]
        ascending_nodes_lvl1 = ascending_nodes_lvl0[ascending_node]
        descending_nodes_lvl1.keys.zip(ascending_nodes_lvl1.keys.reverse).each do |descending_node, ascending_node|
          assert_equal descending_node, ascending_node
          descending_nodes_lvl2 = descending_nodes_lvl1[descending_node]
          ascending_nodes_lvl2 = ascending_nodes_lvl1[ascending_node]
          descending_nodes_lvl2.keys.zip(ascending_nodes_lvl2.keys.reverse).each do |descending_node, ascending_node|
            assert_equal descending_node, ascending_node
            descending_nodes_lvl3 = descending_nodes_lvl2[descending_node]
            ascending_nodes_lvl3 = ascending_nodes_lvl2[ascending_node]
            descending_nodes_lvl3.keys.zip(ascending_nodes_lvl3.keys.reverse).each do |descending_node, ascending_node|
              assert_equal descending_node, ascending_node
            end
          end
        end
      end
    end
  end
end
