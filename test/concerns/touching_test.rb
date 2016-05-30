require_relative '../environment'

class TouchingTest < ActiveSupport::TestCase
  def test_touch_option_disabled
    AncestryTestDatabase.with_model(
      :extra_columns => {:name => :string, :updated_at => :datetime},
      :touch => false
    ) do |model|

      yesterday = Time.now - 1.day
      parent = model.create!(:updated_at => yesterday)
      child  = model.create!(:updated_at => yesterday, :parent => parent)

      child.update_attributes(:name => "Changed")
      assert_equal yesterday, parent.updated_at
    end
  end

  def test_touch_option_enabled
    AncestryTestDatabase.with_model(
      :extra_columns => {:updated_at => :datetime},
      :touch => true
    ) do |model|

      way_back = Time.new(1984)
      recently = Time.now - 1.minute

      parent_1         = model.create!(:updated_at => way_back)
      parent_2         = model.create!(:updated_at => way_back)
      child_1_1        = model.create!(:updated_at => way_back, :parent => parent_1)
      child_1_2        = model.create!(:updated_at => way_back, :parent => parent_1)
      grandchild_1_1_1 = model.create!(:updated_at => way_back, :parent => child_1_1)
      grandchild_1_1_2 = model.create!(:updated_at => way_back, :parent => child_1_1)

      grandchild_1_1_1.parent = parent_2
      grandchild_1_1_1.save!

      assert grandchild_1_1_1.reload.updated_at > recently, "record was not touched"
      assert child_1_1.reload.updated_at        > recently, "old parent was not touched"
      assert parent_1.reload.updated_at         > recently, "old grandparent was not touched"
      assert parent_2.reload.updated_at         > recently, "new parent was not touched"

      assert_equal way_back, grandchild_1_1_2.reload.updated_at, "old sibling was touched"
      assert_equal way_back, child_1_2.reload.updated_at,        "unrelated record was touched"
    end
  end

  def test_touch_option_with_scope
    AncestryTestDatabase.with_model(
      :extra_columns => {:updated_at => :datetime},
      :touch => true
    ) do |model|

      way_back = Time.new(1984)
      recently = Time.now - 1.minute

      parent_1         = model.create!(:updated_at => way_back)
      child_1_1        = model.create!(:updated_at => way_back, :parent => parent_1)
      child_1_2        = model.create!(:updated_at => way_back, :parent => parent_1)
      grandchild_1_1_1 = model.create!(:updated_at => way_back, :parent => child_1_1)

      grandchild_1_1_1.children.create!

      assert_equal way_back, child_1_2.reload.updated_at,    "unrelated record was touched"

      assert grandchild_1_1_1.reload.updated_at  > recently, "parent was not touched"
      assert child_1_1.reload.updated_at         > recently, "grandparent was not touched"
      assert parent_1.reload.updated_at          > recently, "great grandparent was not touched"
    end
  end
end
