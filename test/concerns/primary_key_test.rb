# frozen_string_literal: true

require_relative '../environment'

# Test that ancestry can use a column other than `id` to identify nodes in paths.
class PrimaryKeyTest < ActiveSupport::TestCase
  def with_code_model(**options)
    AncestryTestDatabase.with_model(extra_columns: {code: :string}, primary_key: :code, primary_key_format: :string, **options) do |model|
      yield model
    end
  end

  def test_tree_with_custom_primary_key
    with_code_model do |model|
      root = model.create!(code: 'a')
      child = model.create!(code: 'b', parent: root)
      grandchild = model.create!(code: 'c', parent: child)

      assert_equal [], root.ancestor_ids
      assert_equal ['a'], child.ancestor_ids
      assert_equal ['a', 'b'], grandchild.ancestor_ids

      assert_equal 'a', child.parent_id
      assert_equal 'a', grandchild.root_id

      assert_equal ['a', 'b', 'c'], grandchild.path_ids
    end
  end

  def test_predicates_with_custom_primary_key
    with_code_model do |model|
      root = model.create!(code: 'a')
      child = model.create!(code: 'b', parent: root)

      assert root.root?
      assert root.parent_of?(child)
      assert child.child_of?(root)
      assert root.ancestor_of?(child)
      assert child.descendant_of?(root)
      assert child.in_subtree_of?(root)
    end
  end

  def test_navigation_with_custom_primary_key
    with_code_model do |model|
      root = model.create!(code: 'a')
      child = model.create!(code: 'b', parent: root)
      grandchild = model.create!(code: 'c', parent: child)

      assert_equal root, child.parent
      assert_equal root, grandchild.root
      assert_equal [root, child], grandchild.ancestors.order(:code).to_a
      assert_equal [child, grandchild], root.descendants.order(:code).to_a
    end
  end

  def test_move_with_custom_primary_key
    with_code_model do |model|
      root1 = model.create!(code: 'a')
      root2 = model.create!(code: 'b')
      child = model.create!(code: 'c', parent: root1)

      assert_equal ['a'], child.ancestor_ids

      child.parent = root2
      child.save!
      child.reload

      assert_equal ['b'], child.ancestor_ids
      assert_equal 'b', child.parent_id
    end
  end

  def test_arrange_with_custom_primary_key
    with_code_model do |model|
      root = model.create!(code: 'a')
      child1 = model.create!(code: 'b', parent: root)
      child2 = model.create!(code: 'c', parent: root)

      arranged = model.arrange
      assert_equal 1, arranged.keys.size
      assert_equal 2, arranged[root].keys.size
    end
  end

  def test_model_with_non_id_primary_key
    AncestryTestDatabase.with_model(extra_columns: {code: :string}, primary_key_format: :string, skip_ancestry: true) do |model|
      model.primary_key = :code
      # primary_key: required on Rails < 7.2 (primary_key hits DB on anonymous classes)
      model.has_ancestry primary_key: :code, primary_key_format: :string

      assert_equal :code, model.primary_ancestry_key

      root = model.create!(code: 'a')
      child = model.create!(code: 'b', parent: root)

      assert_equal ['a'], child.ancestor_ids
      assert_equal 'a', child.parent_id
    end
  end
end
