require_relative '../environment'

class OphanStrategiesTest < ActiveSupport::TestCase
  def test_setting_invalid_orphan_strategy
    AncestryTestDatabase.with_model skip_ancestry: true do |model|
      assert_raise Ancestry::AncestryException do
        model.has_ancestry orphan_strategy: :non_existent_orphan_strategy
      end
    end
  end

  def test_orphan_rootify_strategy
    AncestryTestDatabase.with_model orphan_strategy: :rootify, :depth => 3, :width => 3 do |model, roots|
      root = roots.first.first
      children = root.children.to_a
      root.destroy
      children.each do |child|
        child.reload
        assert child.is_root?
        assert_equal 3, child.children.size
      end
    end
  end

  def test_orphan_destroy_strategy
    AncestryTestDatabase.with_model orphan_strategy: :destroy, :depth => 3, :width => 3 do |model, roots|
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
    AncestryTestDatabase.with_model orphan_strategy: :restrict, :depth => 3, :width => 3 do |model, roots|
      root = roots.first.first
      assert_raise Ancestry::AncestryException do
        root.destroy
      end
      assert_nothing_raised do
        root.children.first.children.first.destroy
      end
    end
  end

  def test_orphan_adopt_strategy
    AncestryTestDatabase.with_model orphan_strategy: :adopt do |model|
      n1 = model.create!                  #create a root node
      n2 = model.create!(:parent => n1)   #create child with parent=root
      n3 = model.create!(:parent => n2)   #create child with parent=n2, depth = 2
      n4 = model.create!(:parent => n2)   #create child with parent=n2, depth = 2
      n5 = model.create!(:parent => n4)   #create child with parent=n4, depth = 3
      n2.destroy                          # delete a node with desecendants
      n3.reload
      n5.reload
      assert_equal n3.parent_id, n1.id, "orphan's not parentified"
      assert_equal n5.ancestor_ids, [n1.id, n4.id], "ancestry integrity not maintained"
      n1.destroy                          # delete a root node with desecendants
      n3.reload
      n5.reload
      assert_nil n3.parent_id, " new root node should have no parent"
      assert n3.valid?, " new root node is not valid"
      assert_equal n5.ancestor_ids, [n4.id], "ancestry integrity not maintained"
    end
  end

  def test_override_apply_orphan_strategy
    AncestryTestDatabase.with_model orphan_strategy: :destroy do |model, roots|
      root  = model.create!
      child = model.create!(:parent => root)
      model.class_eval do
        def apply_orphan_strategy
          # disabling destoy callback
        end
      end
      assert_difference 'model.count', -1 do
        root.destroy
      end
      # this should not throw an ActiveRecord::RecordNotFound exception
      assert child.reload.root_id == root.id
    end
  end

  def test_apply_orphan_strategy_none
    AncestryTestDatabase.with_model orphan_strategy: :none do |model, roots|
      root  = model.create!
      child = model.create!(:parent => root)
      model.class_eval do
        def apply_orphan_strategy
          raise "this should not be called"
        end
      end
      assert_difference 'model.count', -1 do
        root.destroy
      end
      # this record should still exist
      assert child.reload.root_id == root.id
    end
  end

  def test_apply_orphan_strategy_custom
    AncestryTestDatabase.with_model orphan_strategy: :none do |model|
      model.class_eval do
        before_destroy :apply_orphan_strategy_abc

        def apply_orphan_strategy_abc
          apply_orphan_strategy_destroy
        end
      end

      root  = model.create!
      3.times { root.children.create! }
      model.create! # a node that is not affected
      assert_difference 'model.count', -4 do
        root.destroy
      end
    end
  end

  # Not supported. Keeping around to explore for future uses.
  def test_apply_orphan_strategy_custom_unsupported
    AncestryTestDatabase.with_model skip_ancestry: true do |model|
      model.class_eval do
        # needs to be defined before calling has_ancestry
        def apply_orphan_strategy_abc
          apply_orphan_strategy_destroy
        end

        has_ancestry orphan_strategy: :abc, ancestry_column: AncestryTestDatabase.ancestry_column
      end
      root  = model.create!
      3.times { root.children.create! }
      model.create! # a node that is not affected
      assert_difference 'model.count', -4 do
        root.destroy
      end
    end
  end

  def test_basic_delete
    AncestryTestDatabase.with_model do |model|
      n1 = model.create!                  #create a root node
      n2 = model.create!(:parent => n1)   #create child with parent=root
      n2.destroy!
      model.find(n1.id)                   # parent should exist

      n1 = model.create!                  #create a root node
      n2 = model.create!(:parent => n1)   #create child with parent=root
      n1.destroy!
      assert_nil(model.find_by(:id => n2.id)) # child should not exist

      n1 = model.create!                  #create a root node
      n1.destroy!
    end
  end
end
