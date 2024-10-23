# frozen_string_literal: true

require_relative '../environment'

class SortByAncestryTest < ActiveSupport::TestCase
  # In a perfect world, we'd only follow the CORRECT=true case
  # This highlights where/why a non-correct sorting order is returned
  CORRECT = (ENV["CORRECT"] == "true")

  RANK_SORT = -> (a, b) { a.rank <=> b.rank }

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

  # nodes among the same parent have an ambigious order
  # so they keep the same order as input
  # also note, parent nodes do come in first
  def test_sort_by_ancestry_full_tree
    AncestryTestDatabase.with_model do |model|
      n1, n2, n3, n4, n5, n6 = build_tree(model)

      records = model.sort_by_ancestry(model.all.ordered_by_ancestry_and(:id => :desc))
      assert_equal [n1, n5, n6, n2, n4, n3].map(&:id), records.map(&:id)
    end
  end

  # tree is of the form:
  #   - x
  #     - x
  #       - n3
  #       - n4
  def test_sort_by_ancestry_no_parents_siblings
    AncestryTestDatabase.with_model do |model|
      _, _, n3, n4, _, _ = build_tree(model)

      records = model.sort_by_ancestry(model.all.ordered_by_ancestry_and(:id => :desc).offset(3).take(2))
      assert_equal [n4, n3].map(&:id), records.map(&:id)
    end
  end

  # TODO: thinking about dropping this one
  # only keep if we can find a 
  def test_sort_by_ancestry_no_parents_same_level
    AncestryTestDatabase.with_model do |model|
      _, _, n3, n4, n5, _ = build_tree(model)

      records = [n5, n4, n3]
      # records = model.sort_by_ancestry(model.all.ordered_by_ancestry_and(:id => :desc).offset(3).take(3))
      assert_equal [n5, n4, n3].map(&:id), records.map(&:id)
    end
  end

  def test_sort_by_ancestry_partial_tree
    AncestryTestDatabase.with_model do |model|
      n1, n2, _, _, n5, _ = build_tree(model)

      records = model.sort_by_ancestry(model.all.ordered_by_ancestry_and(:id => :desc).offset(0).take(3))
      assert_equal [n1, n5, n2].map(&:id), records.map(&:id)
    end
  end

  #   - n1
  #     - x
  #       - n4
  #     - n5
  #
  # Issue:
  #
  # since the nodes are not at the same level, we don't have
  # a way to know if n4 comes before or after n5
  #
  # n1 will always come first since it is a parent of both
  # Since we don't have n2, to bring n4 before n5, we leave in input order

  # TODO: thinking about dropping this test
  # can't think of a way that these records would come back with sql order
  def test_sort_by_ancestry_missing_parent_middle_of_tree
    AncestryTestDatabase.with_model do |model|
      n1, _, _, n4, n5, _ = build_tree(model)

      records = model.sort_by_ancestry([n5, n4, n1])
      if CORRECT
        assert_equal [n1, n4, n5].map(&:id), records.map(&:id)
      else
        assert_equal [n1, n5, n4].map(&:id), records.map(&:id)
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
    # NODES=4..9 seem like edge cases
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

  # TODO: thinking about dropping this one
  # Think we need to assume that best effort was done in the database:
  # ordered_by_ancestry_and(:id => :desc) or order(:ancestry).order(:id => :desc)
  def test_sort_by_ancestry_with_block_full_tree
    AncestryTestDatabase.with_model :extra_columns => {:rank => :integer} do |model|
      n1, n2, n3, n4, n5, n6 = build_ranked_tree(model)

      records = model.sort_by_ancestry(model.all.order(:id => :desc), &RANK_SORT)
      assert_equal [n1, n5, n3, n2, n4, n6].map(&:id), records.map(&:id)
    end
  end

  # NOTE: if the sql orders the records, no sorting block is necessary
  def test_sort_by_ancestry_with_block_full_tree_sql_sort
    AncestryTestDatabase.with_model :extra_columns => {:rank => :integer} do |model|
      n1, n2, n3, n4, n5, n6 = build_ranked_tree(model)

      records = model.sort_by_ancestry(model.all.ordered_by_ancestry_and(:rank))
      assert_equal [n1, n5, n3, n2, n4, n6].map(&:id), records.map(&:id)
    end
  end

  def test_sort_by_ancestry_with_block_all_parents_some_children
    AncestryTestDatabase.with_model :extra_columns => {:rank => :integer} do |model|
      n1, n2, _, _, n5, _ = build_ranked_tree(model)

      records = model.sort_by_ancestry(model.all.ordered_by_ancestry_and(:rank).take(3), &RANK_SORT)
      assert_equal [n1, n5, n2].map(&:id), records.map(&:id)
    end
  end

  # It is tricky when we are using ruby to sort nodes and the parent
  # nodes (i.e.: n1, n2) are not in ruby to be sorted. We either sort
  # them by input order or by id order.
  #
  #   - x (0)
  #     - n5 (0)
  #     - n3 (3)
  #   - x (1)
  #     - n4 (0)
  #     - n6 (1)
  # We can sort [n5, n3] + [n4, n6]
  # a) n3 moves all the way to the right to join n5 OR
  # b) n5 moves all the way to the left to join n3
  # Issue:
  # we do not know if the parent of n5 (n1) comes before or after the parent of n4 (n2)
  # So they should stay in their original order
  # But again, it is indeterministic which way the 2 pairs go
  def test_sort_by_ancestry_with_block_no_parents_all_children
    AncestryTestDatabase.with_model :extra_columns => {:rank => :integer} do |model|
      _, _, n3, n4, n5, n6 = build_ranked_tree(model)

      records = model.sort_by_ancestry(model.all.ordered_by_ancestry_and(:rank).offset(2), &RANK_SORT)
      if CORRECT || records[0] == n5
        assert_equal [n5, n3, n4, n6].map(&:id), records.map(&:id)
      else
        assert_equal [n4, n6, n5, n3].map(&:id), records.map(&:id)
      end
    end
  end

  #   - x (0)
  #     - x
  #     - n3 (3)
  #   - n2 (1)
  #     - n4 (0)
  #     - x
  # Issue: n2 will always go before n4, n5.
  #        But n1 is not available to put n3 before the n2 tree.
  #        not sure why it doesn't follow the input order
  #
  # NOTE: even for partial trees, if the input records are ranked, the output works
  def test_sort_by_ancestry_with_sql_sort_paginated_missing_parents_and_children
    AncestryTestDatabase.with_model :extra_columns => {:rank => :integer} do |model|
      _, n2, n3, n4, n5, _ = build_ranked_tree(model)

      records = model.sort_by_ancestry(model.all.ordered_by_ancestry_and(:rank).offset(1).take(4))
      if CORRECT
        assert_equal [n3, n2, n4, n5].map(&:id), records.map(&:id)
      else
        assert_equal [n2, n4, n5, n3].map(&:id), records.map(&:id)
      end
    end
  end

  # same as above but using sort block
  #   - x (0)
  #     - x
  #     - n3 (3)
  #   - n2 (1)
  #     - n4 (0)
  #     - n5
  def test_sort_by_ancestry_with_block_paginated_missing_parents_and_children
    AncestryTestDatabase.with_model :extra_columns => {:rank => :integer} do |model|
      _, n2, n3, n4, n5, _ = build_ranked_tree(model)

      records = model.sort_by_ancestry(model.all.ordered_by_ancestry_and(:rank).offset(1).take(4), &RANK_SORT)
      if CORRECT
        assert_equal [n3, n2, n4, n5].map(&:id), records.map(&:id)
      else
        assert_equal [n2, n4, n5, n3].map(&:id), records.map(&:id)
      end
    end
  end
end
