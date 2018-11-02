require_relative '../environment'

class SortByAncestryTest < ActiveSupport::TestCase
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

  def xtest_sort_by_ancestry_missing_parent_middle_of_tree
    AncestryTestDatabase.with_model do |model|
      n1, n2, n3, n4, n5, n6 = build_tree(model)

      assert_equal [n1, n5, n4].map(&:id), model.sort_by_ancestry([n5, n4, n1]).map(&:id)
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

      records = model.sort_by_ancestry(model.all.order(:rank).reverse, &sort)
      assert_equal [n1, n5, n3, n2, n4, n6].map(&:id), records.map(&:id)
    end
  end

  def test_sort_by_ancestry_with_block_all_parents_some_children
    AncestryTestDatabase.with_model :extra_columns => {:rank => :integer} do |model|
      n1, n2, n3, n4, n5, n6 = build_ranked_tree(model)
      sort = -> (a, b) { a.rank <=> b.rank }

      assert_equal [n1, n5, n2].map(&:id), model.sort_by_ancestry([n2, n1, n5], &sort).map(&:id)
    end
  end

  def test_sort_by_ancestry_with_block_no_parents_all_children
    AncestryTestDatabase.with_model :extra_columns => {:rank => :integer} do |model|
      n1, n2, n3, n4, n5, n6 = build_ranked_tree(model)
      sort = -> (a, b) { a.rank <=> b.rank }

      assert_equal [n5, n3, n4, n6].map(&:id), model.sort_by_ancestry([n3, n4, n5, n6], &sort).map(&:id)
    end
  end

  # NOTE: this is non ranked. included to compare and contrast with ranked version
  # TODO: arrange_nodes broken, dropping some parentless nodes
  def xtest_sort_by_ancestry_paginated_missing_parents_and_children
    AncestryTestDatabase.with_model :extra_columns => {:rank => :integer} do |model|
      n1, n2, n3, n4, n5, n6 = build_ranked_tree(model)
      sort = -> (a, b) { a.rank <=> b.rank }

      records = model.sort_by_ancestry(model.all.order(:rank).reverse)
      assert_equal [n3, n2, n4].map(&:id), model.sort_by_ancestry([n3, n2, n4]).map(&:id)
    end
  end

  # TODO: arrange_nodes broken, dropping some parentless nodes
  def xtest_sort_by_ancestry_with_block_paginated_missing_parents_and_children
    AncestryTestDatabase.with_model :extra_columns => {:rank => :integer} do |model|
      n1, n2, n3, n4, n5, n6 = build_ranked_tree(model)
      sort = -> (a, b) { a.rank <=> b.rank }

      records = model.sort_by_ancestry(model.all.order(:rank).reverse, &sort)
      assert_equal [n3, n2, n4].map(&:id), model.sort_by_ancestry([n3, n2, n4], &sort).map(&:id)
    end
  end
end
