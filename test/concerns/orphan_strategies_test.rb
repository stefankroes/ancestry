require_relative '../environment'

class OphanStrategiesTest < ActiveSupport::TestCase
  def test_default_orphan_strategy
    AncestryTestDatabase.with_model do |model|
      assert_equal :destroy, model.orphan_strategy
    end
  end

  def test_non_default_orphan_strategy
    AncestryTestDatabase.with_model orphan_strategy: :rootify do |model|
      assert_equal :rootify, model.orphan_strategy
    end
  end

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
      assert_equal(model.find(n3.id).parent,n1, "orphan's not parentified" )
      assert_equal(model.find(n5.id).ancestor_ids, [n1.id,n4.id], "ancestry integrity not maintained")
      n1.destroy                          # delete a root node with desecendants
      if model.ancestry_format == :materialized_path2
        assert_equal(model.find(n3.id).ancestry, model.ancestry_root, " new root node has no root ancestry string")
      else
        assert_nil(model.find(n3.id).ancestry," new root node has no empty ancestry string")
      end
      assert_equal(model.find(n3.id).valid?, true, " new root node is not valid")
      assert_nil(model.find(n3.id).parent_id, " Children of the deleted root not rootfied")
      assert_equal(model.find(n5.id).ancestor_ids, [n4.id], "ancestry integrity not maintained")
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
