require_relative '../environment'

class SortByAncestryTest < ActiveSupport::TestCase
  # in a perfect world, we'd only follow the CORRECT=true case
  # but when not enough information is available, the STRICT=true case is good enough
  #
  # these flags are to allow multiple values for correct for tests
  CORRECT = (ENV["CORRECT"] == "true")
  STRICT = (ENV["STRICT"] == "true")

  # tree is of the form:
  #   - n1
  #     - n2
  #       - n3
  #       - n4
  #     - n5
  #       - n6
  # @returns [Array<model>] list of nodes
  def build_tree(model)
    # inflate the node id to test id wrap around edge cases
    ENV["NODES"].to_i.times { model.create!.destroy } if ENV["NODES"]

    n1 = model.create!
    n2 = model.create!(:parent => n1)
    n3 = model.create!(:parent => n2)
    n4 = model.create!(:parent => n2)
    n5 = model.create!(:parent => n1)
    n6 = model.create!(:parent => n5)

    puts "create: #{n1.id}..#{n6.id}" if ENV["NODES"]
    [n1, n2, n3, n4, n5, n6]
  end

  def test_sort_by_ancestry_full_tree
    AncestryTestDatabase.with_model do |model|
      n1, n2, n3, n4, n5, n6 = build_tree(model)

      records = model.sort_by_ancestry(model.all.order(:id).reverse)
      assert_equal [n1, n5, n6, n2, n4, n3].map(&:id), records.map(&:id)
    end
  end

  def test_sort_by_ancestry_no_parents_siblings
    AncestryTestDatabase.with_model do |model|
      n1, n2, n3, n4, n5, n6 = build_tree(model)

      assert_equal [n4, n3].map(&:id), model.sort_by_ancestry([n4, n3]).map(&:id)
    end
  end

  # TODO: don't drop parentless nodes
  def xtest_sort_by_ancestry_no_parents_same_level
    AncestryTestDatabase.with_model do |model|
      n1, n2, n3, n4, n5, n6 = build_tree(model)

      assert_equal [n5, n4, n3].map(&:id), model.sort_by_ancestry([n5, n4, n3]).map(&:id)
    end
  end

  def test_sort_by_ancestry_partial_tree
    AncestryTestDatabase.with_model do |model|
      n1, n2, n3, n4, n5, n6 = build_tree(model)

      assert_equal [n1, n5, n2].map(&:id), model.sort_by_ancestry([n5, n2, n1]).map(&:id)
    end
  end

  # TODO: don't drop parentless nodes
  def xtest_sort_by_ancestry_missing_parent_middle_of_tree
    AncestryTestDatabase.with_model do |model|
      n1, n2, n3, n4, n5, n6 = build_tree(model)

      records = model.sort_by_ancestry([n5, n4, n1])
      if (!CORRECT) && (STRICT || records[1] == n5)
        assert_equal [n1, n5, n4].map(&:id), records.map(&:id)
      else
        assert_equal [n1, n4, n5].map(&:id), records.map(&:id)
      end
    end
  end

  # tree is of the form
  #   - n1 (0)
  #     - n5 (0)
  #     - n3 (3)
  #   - n2 (1)
  #     - n4 (0)
  #     - n6 (1)
  # @returns [Array<model>] list of ranked nodes
  def build_ranked_tree(model)
    # inflate the node id to test id wrap around edge cases
    ENV["NODES"].to_i.times { model.create!.destroy } if ENV["NODES"]

    n1 = model.create!(:rank => 0)
    n2 = model.create!(:rank => 1)
    n3 = model.create!(:rank => 3, :parent => n1)
    n4 = model.create!(:rank => 0, :parent => n2)
    n5 = model.create!(:rank => 0, :parent => n1)
    n6 = model.create!(:rank => 1, :parent => n2)

    puts "create: #{n1.id}..#{n6.id}" if ENV["NODES"]
    [n1, n2, n3, n4, n5, n6]
  end

  def test_sort_by_ancestry_with_block_full_tree
    AncestryTestDatabase.with_model :extra_columns => {:rank => :integer} do |model|
      n1, n2, n3, n4, n5, n6 = build_ranked_tree(model)
      sort = -> (a, b) { a.rank <=> b.rank }

      records = model.sort_by_ancestry(model.all.order(:id).reverse, &sort)
      assert_equal [n1, n5, n3, n2, n4, n6].map(&:id), records.map(&:id)
    end
  end

  # NOTE: if the sql orders the records, no sorting block is necessary
  def test_sort_by_ancestry_with_block_full_tree_sql_sort
    AncestryTestDatabase.with_model :extra_columns => {:rank => :integer} do |model|
      n1, n2, n3, n4, n5, n6 = build_ranked_tree(model)

      records = model.sort_by_ancestry(model.all.order(:rank))
      assert_equal [n1, n5, n3, n2, n4, n6].map(&:id), records.map(&:id)
    end
  end

  def test_sort_by_ancestry_with_block_all_parents_some_children
    AncestryTestDatabase.with_model :extra_columns => {:rank => :integer} do |model|
      n1, n2, n3, n4, n5, n6 = build_ranked_tree(model)
      sort = -> (a, b) { a.rank <=> b.rank }

      assert_equal [n1, n5, n2].map(&:id), model.sort_by_ancestry([n1, n2, n5], &sort).map(&:id)
    end
  end

  # seems the best we can do is to have [5,3] + [4,6]
  # if we follow input order, we can end up with either result
  # a) n3 moves all the way to the right or b) n5 moves all the way to the left
  # TODO: find a way to rank missing nodes
  def test_sort_by_ancestry_with_block_no_parents_all_children
    AncestryTestDatabase.with_model :extra_columns => {:rank => :integer} do |model|
      n1, n2, n3, n4, n5, n6 = build_ranked_tree(model)
      sort = -> (a, b) { a.rank <=> b.rank }

      records = model.sort_by_ancestry([n3, n4, n5, n6], &sort)
      if CORRECT || records[0] == n5
        assert_equal [n5, n3, n4, n6].map(&:id), records.map(&:id)
      else
        assert_equal [n4, n6, n5, n3].map(&:id), records.map(&:id)
      end
    end
  end

  # TODO: don't drop parentless nodes
  # TODO: nodes need to follow original ordering
  # NOTE: even for partial trees, if the input records are ranked, the output works
  def xtest_sort_by_ancestry_with_sql_sort_paginated_missing_parents_and_children
    AncestryTestDatabase.with_model :extra_columns => {:rank => :integer} do |model|
      n1, n2, n3, n4, n5, n6 = build_ranked_tree(model)

      records = model.sort_by_ancestry([n2, n4, n3])
      if (!CORRECT) && (STRICT || records[0] == n2)
        assert_equal [n2, n4, n3].map(&:id), records.map(&:id)
      else
        assert_equal [n3, n2, n4].map(&:id), records.map(&:id)
      end
    end
  end

  # in a perfect world, the second case would be matched
  # but since presorting is not used, the best we can assume from input order is that n1 > n2
  # TODO: don't drop parentless nodes
  # TODO: follow input order
  # TODO: find a way to rank missing nodes
  def xtest_sort_by_ancestry_with_block_paginated_missing_parents_and_children
    AncestryTestDatabase.with_model :extra_columns => {:rank => :integer} do |model|
      n1, n2, n3, n4, n5, n6 = build_ranked_tree(model)
      sort = -> (a, b) { a.rank <=> b.rank }

      records = model.sort_by_ancestry([n2, n4, n3], &sort)
      if (!CORRECT) && (STRICT || records[0] == n2)
        assert_equal [n2, n4, n3].map(&:id), records.map(&:id)
      else
        assert_equal [n3, n2, n4].map(&:id), records.map(&:id)
      end
    end
  end
end
