require File.join(File.expand_path(File.dirname(__FILE__)), "environment")

class HasAncestryTreeTest < ActiveSupport::TestCase
  def test_default_ancestry_column
    AncestryTestDatabase.with_model do |model|
      assert_equal :ancestry, model.ancestry_column
    end
  end

  def test_non_default_ancestry_column
    AncestryTestDatabase.with_model :ancestry_column => :alternative_ancestry do |model|
      assert_equal :alternative_ancestry, model.ancestry_column
    end
  end

  def test_setting_ancestry_column
    AncestryTestDatabase.with_model do |model|
      model.ancestry_column = :ancestors
      assert_equal :ancestors, model.ancestry_column
      model.ancestry_column = :ancestry
      assert_equal :ancestry, model.ancestry_column
    end
  end

  def test_default_orphan_strategy
    AncestryTestDatabase.with_model do |model|
      assert_equal :destroy, model.orphan_strategy
    end
  end

  def test_non_default_orphan_strategy
    AncestryTestDatabase.with_model :orphan_strategy => :rootify do |model|
      assert_equal :rootify, model.orphan_strategy
    end
  end

  def test_setting_orphan_strategy
    AncestryTestDatabase.with_model do |model|
      model.orphan_strategy = :rootify
      assert_equal :rootify, model.orphan_strategy
      model.orphan_strategy = :destroy
      assert_equal :destroy, model.orphan_strategy
    end
  end

  def test_setting_invalid_orphan_strategy
    AncestryTestDatabase.with_model do |model|
      assert_raise Ancestry::AncestryException do
        model.orphan_strategy = :non_existent_orphan_strategy
      end
    end
  end

  def test_setup_test_nodes
    AncestryTestDatabase.with_model :depth => 3, :width => 3 do |model, roots|
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
    AncestryTestDatabase.with_model :depth => 3, :width => 3 do |model, roots|
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

  def test_ancestors_with_string_primary_keys
    AncestryTestDatabase.with_model :depth => 3, :width => 3, :primary_key_type => :string, :primary_key_format => /[a-z0-9]+/ do |model, roots|
      roots.each do |lvl0_node, lvl0_children|
        # Ancestors assertions
        assert_equal [], lvl0_node.ancestor_ids
        assert_equal [], lvl0_node.ancestors
        assert_equal [lvl0_node.id], lvl0_node.path_ids
        assert_equal [lvl0_node], lvl0_node.path
        assert_equal 0, lvl0_node.depth
        lvl0_children.each do |lvl1_node, lvl1_children|
          # Ancestors assertions
          assert_equal [lvl0_node.id], lvl1_node.ancestor_ids
          assert_equal [lvl0_node], lvl1_node.ancestors
          assert_equal [lvl0_node.id, lvl1_node.id], lvl1_node.path_ids
          assert_equal [lvl0_node, lvl1_node], lvl1_node.path
          assert_equal 1, lvl1_node.depth
          lvl1_children.each do |lvl2_node, lvl2_children|
            # Ancestors assertions
            assert_equal [lvl0_node.id, lvl1_node.id], lvl2_node.ancestor_ids
            assert_equal [lvl0_node, lvl1_node], lvl2_node.ancestors
            assert_equal [lvl0_node.id, lvl1_node.id, lvl2_node.id], lvl2_node.path_ids
            assert_equal [lvl0_node, lvl1_node, lvl2_node], lvl2_node.path
            assert_equal 2, lvl2_node.depth
          end
        end
      end
    end
  end

  def test_scopes
    AncestryTestDatabase.with_model :depth => 3, :width => 3 do |model, roots|
      # Roots assertion
      assert_equal roots.map(&:first), model.roots.all

      model.all.each do |test_node|
        # Assertions for ancestors_of named scope
        assert_equal test_node.ancestors.all, model.ancestors_of(test_node).all
        assert_equal test_node.ancestors.all, model.ancestors_of(test_node.id).all
        # Assertions for children_of named scope
        assert_equal test_node.children.all, model.children_of(test_node).all
        assert_equal test_node.children.all, model.children_of(test_node.id).all
        # Assertions for descendants_of named scope
        assert_equal test_node.descendants.all, model.descendants_of(test_node).all
        assert_equal test_node.descendants.all, model.descendants_of(test_node.id).all
        # Assertions for subtree_of named scope
        assert_equal test_node.subtree.all, model.subtree_of(test_node).all
        assert_equal test_node.subtree.all, model.subtree_of(test_node.id).all
        # Assertions for siblings_of named scope
        assert_equal test_node.siblings.all, model.siblings_of(test_node).all
        assert_equal test_node.siblings.all, model.siblings_of(test_node.id).all
      end
    end
  end

  def test_ancestry_column_validation
    AncestryTestDatabase.with_model do |model|
      node = model.create
      ['3', '10/2', '1/4/30', nil].each do |value|
        node.send :write_attribute, model.ancestry_column, value
        node.valid?; assert node.errors[model.ancestry_column].blank?
      end
      ['1/3/', '/2/3', 'a', 'a/b', '-34', '/54'].each do |value|
        node.send :write_attribute, model.ancestry_column, value
        node.valid?; assert !node.errors[model.ancestry_column].blank?
      end
    end

    AncestryTestDatabase.with_model :primary_key_format => /[0-9a-z]+/ do |model|
      node = model.create
      ['xk7', '9x1/l4n', 'r1c/4z9/8ps', nil].each do |value|
        node.send :write_attribute, model.ancestry_column, value
        node.valid?; assert node.errors[model.ancestry_column].blank?
      end
      ['s9a/xk2/', '/s92/d92', 'X', 'X/Y', 'S23', '/xk2'].each do |value|
        node.send :write_attribute, model.ancestry_column, value
        node.valid?; assert !node.errors[model.ancestry_column].blank?
      end
    end
  end

  def test_descendants_move_with_node
    AncestryTestDatabase.with_model :depth => 3, :width => 3 do |model, roots|
      root1, root2, root3 = roots.map(&:first)
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
  end

  def test_orphan_rootify_strategy
    AncestryTestDatabase.with_model :depth => 3, :width => 3 do |model, roots|
      model.orphan_strategy = :rootify
      root = roots.first.first
      children = root.children.all
      root.destroy
      children.each do |child|
        child.reload
        assert child.is_root?
        assert_equal 3, child.children.size
      end
    end
  end

  def test_orphan_destroy_strategy
    AncestryTestDatabase.with_model :depth => 3, :width => 3 do |model, roots|
      model.orphan_strategy = :destroy
      root = roots.first.first
      assert_difference 'model.count', -root.subtree.size do
        root.destroy
      end
      node = model.roots.first.children.first
      assert_difference 'model.count', -node.subtree.size do
        node.destroy
      end
    end
  end

  def test_orphan_restrict_strategy
    AncestryTestDatabase.with_model :depth => 3, :width => 3 do |model, roots|
      model.orphan_strategy = :restrict
      root = roots.first.first
      assert_raise Ancestry::AncestryException do
        root.destroy
      end
      assert_nothing_raised Ancestry::AncestryException do
        root.children.first.children.first.destroy
      end
    end
  end

  def test_integrity_checking
    AncestryTestDatabase.with_model :width => 3, :depth => 3 do |model, roots|
      # Check that there are no errors on a valid tree
      assert_nothing_raised do
        model.check_ancestry_integrity!
      end
      assert_equal 0, model.check_ancestry_integrity!(:report => :list).size
    end

    AncestryTestDatabase.with_model :width => 3, :depth => 3 do |model, roots|
      # Check detection of invalid format for ancestry column
      roots.first.first.update_attribute model.ancestry_column, 'invalid_ancestry'
      assert_raise Ancestry::AncestryIntegrityException do
        model.check_ancestry_integrity!
      end
      assert_equal 1, model.check_ancestry_integrity!(:report => :list).size
    end

    AncestryTestDatabase.with_model :width => 3, :depth => 3 do |model, roots|
      # Check detection of non-existent ancestor
      roots.first.first.update_attribute model.ancestry_column, 35
      assert_raise Ancestry::AncestryIntegrityException do
        model.check_ancestry_integrity!
      end
      assert_equal 1, model.check_ancestry_integrity!(:report => :list).size
    end

    AncestryTestDatabase.with_model :width => 3, :depth => 3 do |model, roots|
      # Check detection of cyclic ancestry
      node = roots.first.first
      node.update_attribute model.ancestry_column, node.id
      assert_raise Ancestry::AncestryIntegrityException do
        model.check_ancestry_integrity!
      end
      assert_equal 1, model.check_ancestry_integrity!(:report => :list).size
    end

    AncestryTestDatabase.with_model do |model|
      # Check detection of conflicting parent id
      model.destroy_all
      model.create!(model.ancestry_column => model.create!(model.ancestry_column => model.create!(model.ancestry_column => nil).id).id)
      assert_raise Ancestry::AncestryIntegrityException do
        model.check_ancestry_integrity!
      end
      assert_equal 1, model.check_ancestry_integrity!(:report => :list).size
    end
  end

  def assert_integrity_restoration model
    assert_raise Ancestry::AncestryIntegrityException do
      model.check_ancestry_integrity!
    end
    model.restore_ancestry_integrity!
    assert_nothing_raised do
      model.check_ancestry_integrity!
    end
  end

  def test_integrity_restoration
    # Check that integrity is restored for invalid format for ancestry column
    AncestryTestDatabase.with_model :width => 3, :depth => 3 do |model, roots|
      roots.first.first.update_attribute model.ancestry_column, 'invalid_ancestry'
      assert_integrity_restoration model
    end

    # Check that integrity is restored for non-existent ancestor
    AncestryTestDatabase.with_model :width => 3, :depth => 3 do |model, roots|
      roots.first.first.update_attribute model.ancestry_column, 35
      assert_integrity_restoration model
    end

    # Check that integrity is restored for cyclic ancestry
    AncestryTestDatabase.with_model :width => 3, :depth => 3 do |model, roots|
      node = roots.first.first
      node.update_attribute model.ancestry_column, node.id
      assert_integrity_restoration model
    end

    # Check that integrity is restored for conflicting parent id
    AncestryTestDatabase.with_model do |model|
      model.destroy_all
      model.create!(model.ancestry_column => model.create!(model.ancestry_column => model.create!(model.ancestry_column => nil).id).id)
      assert_integrity_restoration model
    end
  end

  def test_arrangement
    AncestryTestDatabase.with_model :depth => 3, :width => 3 do |model, roots|
      id_sorter = Proc.new do |a, b|; a.id <=> b.id; end
      arranged_nodes = model.arrange
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
  end

  def test_node_creation_though_scope
    AncestryTestDatabase.with_model do |model|
      node = model.create!
      child = node.children.create
      assert_equal node, child.parent

      other_child = child.siblings.create!
      assert_equal node, other_child.parent

      grandchild = model.children_of(child).new
      grandchild.save
      assert_equal child, grandchild.parent

      other_grandchild = model.siblings_of(grandchild).new
      other_grandchild.save!
      assert_equal child, other_grandchild.parent
    end
  end

  def test_validate_ancestry_exclude_self
    AncestryTestDatabase.with_model do |model|
      parent = model.create!
      child = parent.children.create!
      assert_raise ActiveRecord::RecordInvalid do
        parent.update_attributes! :parent => child
      end
    end
  end

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

  def test_invalid_has_ancestry_options
    assert_raise Ancestry::AncestryException do
      Class.new(ActiveRecord::Base).has_ancestry :this_option_doesnt_exist => 42
    end
    assert_raise Ancestry::AncestryException do
      Class.new(ActiveRecord::Base).has_ancestry :not_a_hash
    end
  end

  def test_build_ancestry_from_parent_ids
    AncestryTestDatabase.with_model :skip_ancestry => true, :extra_columns => {:parent_id => :integer} do |model|
      [model.create!].each do |parent|
        (Array.new(5) { model.create! :parent_id => parent.id }).each do |parent|
          (Array.new(5) { model.create! :parent_id => parent.id }).each do |parent|
            (Array.new(5) { model.create! :parent_id => parent.id })
          end
        end
      end

      # Assert all nodes where created
      assert_equal (0..3).map { |n| 5 ** n }.sum, model.count

      model.has_ancestry
      model.build_ancestry_from_parent_ids!

      # Assert ancestry integrity
      assert_nothing_raised do
        model.check_ancestry_integrity!
      end

      roots = model.roots.all
      # Assert single root node
      assert_equal 1, roots.size

      # Assert it has 5 children
      roots.each do |parent|
        assert_equal 5, parent.children.count
        parent.children.each do |parent|
          assert_equal 5, parent.children.count
          parent.children.each do |parent|
            assert_equal 5, parent.children.count
            parent.children.each do |parent|
              assert_equal 0, parent.children.count
            end
          end
        end
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

  def test_descendants_with_depth_constraints
    AncestryTestDatabase.with_model :depth => 4, :width => 4, :cache_depth => true do |model, roots|
      assert_equal 4, model.roots.first.descendants(:before_depth => 2).count
      assert_equal 20, model.roots.first.descendants(:to_depth => 2).count
      assert_equal 16, model.roots.first.descendants(:at_depth => 2).count
      assert_equal 80, model.roots.first.descendants(:from_depth => 2).count
      assert_equal 64, model.roots.first.descendants(:after_depth => 2).count
    end
  end

  def test_subtree_with_depth_constraints
    AncestryTestDatabase.with_model :depth => 4, :width => 4, :cache_depth => true do |model, roots|
      assert_equal 5, model.roots.first.subtree(:before_depth => 2).count
      assert_equal 21, model.roots.first.subtree(:to_depth => 2).count
      assert_equal 16, model.roots.first.subtree(:at_depth => 2).count
      assert_equal 80, model.roots.first.subtree(:from_depth => 2).count
      assert_equal 64, model.roots.first.subtree(:after_depth => 2).count
    end
  end


  def test_ancestors_with_depth_constraints
    AncestryTestDatabase.with_model :cache_depth => true do |model|
      node1 = model.create!
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
  end

  def test_path_with_depth_constraints
    AncestryTestDatabase.with_model :cache_depth => true do |model|
      node1 = model.create!
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
  end

  def test_exception_on_unknown_depth_column
    AncestryTestDatabase.with_model :cache_depth => true do |model|
      assert_raise Ancestry::AncestryException do
        model.create!.subtree(:this_is_not_a_valid_depth_option => 42)
      end
    end
  end

  def test_sti_support
    AncestryTestDatabase.with_model :extra_columns => {:type => :string} do |model|
      subclass1 = Object.const_set 'Subclass1', Class.new(model)
      (class << subclass1; self; end).send :define_method, :model_name do; Struct.new(:human, :underscore).new 'Subclass1', 'subclass1'; end
      subclass2 = Object.const_set 'Subclass2', Class.new(model)
      (class << subclass2; self; end).send :define_method, :model_name do; Struct.new(:human, :underscore).new 'Subclass1', 'subclass1'; end

      node1 = subclass1.create!
      node2 = subclass2.create! :parent => node1
      node3 = subclass1.create! :parent => node2
      node4 = subclass2.create! :parent => node3
      node5 = subclass1.create! :parent => node4

      model.all.each do |node|
        assert [subclass1, subclass2].include?(node.class)
      end

      assert_equal [node2.id, node3.id, node4.id, node5.id], node1.descendants.map(&:id)
      assert_equal [node1.id, node2.id, node3.id, node4.id, node5.id], node1.subtree.map(&:id)
      assert_equal [node1.id, node2.id, node3.id, node4.id], node5.ancestors.map(&:id)
      assert_equal [node1.id, node2.id, node3.id, node4.id, node5.id], node5.path.map(&:id)
    end
  end

  def test_arrange_order_option
    AncestryTestDatabase.with_model :width => 3, :depth => 3 do |model, roots|
      descending_nodes_lvl0 = model.arrange :order => 'id desc'
      ascending_nodes_lvl0 = model.arrange :order => 'id asc'

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
