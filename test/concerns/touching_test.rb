# frozen_string_literal: true

require_relative '../environment'

class TouchingTest < ActiveSupport::TestCase
  def test_touch_option_disabled
    AncestryTestDatabase.with_model(
      :extra_columns => {:name => :string, :updated_at => :datetime},
      :touch => false
    ) do |model|

      wayback = Time.new(1984)
      recently = Time.now - 1.minute

      parent = model.create!
      child  = model.create!(:parent => parent)
      model.update_all(:updated_at => wayback)

      child.reload.update(:name => "Changed")
      assert child.reload.updated_at >= recently, "record updated_at was not changed"
      assert parent.reload.updated_at < recently, "parent updated_at was changed"
    end
  end

  def test_touch_option_enabled_propagates_with_modification
    AncestryTestDatabase.with_model(
      :extra_columns => {:updated_at => :datetime},
      :touch => true
    ) do |model|

      way_back = Time.new(1984)
      recently = Time.now - 1.minute

      parent_1         = model.create!
      parent_2         = model.create!
      child_1_1        = model.create!(:parent => parent_1)
      child_1_2        = model.create!(:parent => parent_1)
      grandchild_1_1_1 = model.create!(:parent => child_1_1)
      grandchild_1_1_2 = model.create!(:parent => child_1_1)
      # creating children update all the fields. this clears them back
      model.update_all(:updated_at => way_back)

      grandchild_1_1_1.reload.update!(parent: parent_2)

      assert grandchild_1_1_1.reload.updated_at >= recently, "record was not touched"
      assert child_1_1.reload.updated_at        >= recently, "old parent was not touched"
      assert parent_1.reload.updated_at         >= recently, "old grandparent was not touched"
      assert parent_2.reload.updated_at         >= recently, "new parent was not touched"

      assert_equal way_back, grandchild_1_1_2.reload.updated_at, "old sibling was touched"
      assert_equal way_back, child_1_2.reload.updated_at,        "unrelated record was touched"
    end
  end

  def test_touch_propogates_multiple_levels
    AncestryTestDatabase.with_model(:extra_columns => {:name => :string, :updated_at => :datetime}, :touch => true) do |model|

      way_back = Time.new(1984)
      recently = Time.now - 1.minute

      node1    = model.create!(:name => "n1")
      node2    = model.create!(:name => "n2")
      node3    = model.create!(:name => "n3")
      node11   = model.create!(:name => "n11", :parent => node1)
      node111  = model.create!(:name => "n111", :parent => node11)
      node1111 = model.create!(:name => "n1111", :parent => node111)
      # creating children update all the fields. this clears them back
      model.update_all(:updated_at => way_back)

      node11.reload.update!(:parent => node2)

      assert node1.reload.updated_at    >= recently, "old parent was not touched"
      assert node2.reload.updated_at    >= recently, "new parent was not touched"
      assert node3.reload.updated_at    <  recently, "uncle was touched"
      assert node11.reload.updated_at   >= recently, "record was not touched"
      assert node111.reload.updated_at  >= recently, "child was not touched"
      assert node1111.reload.updated_at >= recently, "child was not touched"
    end
  end

  # this is touching records only if the ancestry changed
  def test_touch_option_enabled_doesnt_propagate_without_modification
    AncestryTestDatabase.with_model(
      :extra_columns => {:updated_at => :datetime},
      :touch => true
    ) do |model|

      way_back = Time.new(1984)
      recently = Time.now - 1.minute

      node1   = model.create!
      node11  = node1.children.create!
      node111 = node11.children.create!
      # creating children update all the fields. this clears them back
      model.update_all(updated_at: way_back)

      node111.save!

      assert node111.reload.updated_at < recently, "main record updated_at timestamp was touched"
      assert node11.reload.updated_at  < recently, "parent record was touched"
      assert node1.reload.updated_at   < recently, "grandparent record was touched"
    end
  end

  def test_touch_option_with_scope
    AncestryTestDatabase.with_model(
      :extra_columns => {:updated_at => :datetime},
      :touch => true
    ) do |model|

      way_back = Time.new(1984)
      recently = Time.now - 1.minute

      parent_1         = model.create!
      child_1_1        = model.create!(:parent => parent_1)
      child_1_2        = model.create!(:parent => parent_1)
      grandchild_1_1_1 = model.create!(:parent => child_1_1)
      model.update_all(:updated_at => way_back)
      grandchild_1_1_1.children.create!

      assert_equal way_back, child_1_2.reload.updated_at,    "unrelated record was touched"

      assert grandchild_1_1_1.reload.updated_at  > recently, "parent was not touched"
      assert child_1_1.reload.updated_at         > recently, "grandparent was not touched"
      assert parent_1.reload.updated_at          > recently, "great grandparent was not touched"
    end
  end
end
