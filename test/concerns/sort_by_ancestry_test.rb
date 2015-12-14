require_relative '../environment'

class SortByAncestryTest < ActiveSupport::TestCase
  def test_sort_by_ancestry
    AncestryTestDatabase.with_model do |model|
      # - n1
      #   - n2
      #     - n3
      #     - n4
      #   - n5
      n1 = model.create!
      n2 = model.create!(:parent => n1)
      n3 = model.create!(:parent => n2)
      n4 = model.create!(:parent => n2)
      n5 = model.create!(:parent => n1)

      records = model.sort_by_ancestry(model.all.sort_by(&:id).reverse)
      if records[1] == n2
        if records[2] == n3
          assert_equal [n1, n2, n3, n4, n5].map(&:id), records.map(&:id)
        else
          assert_equal [n1, n2, n4, n3, n5].map(&:id), records.map(&:id)
        end
      else
        if records[3] == n3
          assert_equal [n1, n5, n2, n3, n4].map(&:id), records.map(&:id)
        else
          assert_equal [n1, n5, n2, n4, n3].map(&:id), records.map(&:id)
        end
      end
    end
  end

  def test_sort_by_ancestry_with_block
    AncestryTestDatabase.with_model :extra_columns => {:rank => :integer} do |model|
      n1 = model.create!(:rank => 0)
      n2 = model.create!(:rank => 1)
      n3 = model.create!(:rank => 0, :parent => n1)
      n4 = model.create!(:rank => 0, :parent => n2)
      n5 = model.create!(:rank => 1, :parent => n1)
      n6 = model.create!(:rank => 1, :parent => n2)

      records = model.sort_by_ancestry(model.all.sort_by(&:rank).reverse) {|a, b| a.rank <=> b.rank}
      assert_equal [n1, n3, n5, n2, n4, n6].map(&:id), records.map(&:id)
    end
  end
end
