# frozen_string_literal: true

require "securerandom"
require_relative '../environment'

# UUID primary key support.
# ancestry column is always string — stores paths like "uuid1/uuid2/uuid3".
# primary_key_format must match UUID pattern for validation.
class UuidTest < ActiveSupport::TestCase
  # SQLite has no native UUID type — use string PK with Ruby-generated UUIDs
  # ltree does not support UUIDs — labels only allow [A-Za-z0-9_], no hyphens
  UUID_OPTIONS = {id: :string, primary_key_format: :uuid}.freeze

  def with_uuid_model(**options)
    skip "ltree labels do not support hyphens (UUID format)" if AncestryTestDatabase.ltree?
    skip "array format only supports integer values" if AncestryTestDatabase.array?
    AncestryTestDatabase.with_model(**UUID_OPTIONS, **options) do |model|
      model.before_create { self.id = SecureRandom.uuid if id.blank? }
      yield model
    end
  end

  def test_basic_tree_operations
    with_uuid_model do |model|
      root = model.create!
      child = model.create!(parent: root)
      grandchild = model.create!(parent: child)

      assert_kind_of String, root.id

      assert_equal [root.id, child.id], grandchild.ancestor_ids
      assert_equal child.id, grandchild.parent_id
      assert_equal root.id, grandchild.root_id
      assert_equal 2, grandchild.depth
      assert_equal [root.id, child.id, grandchild.id], grandchild.path_ids
    end
  end

  def test_move_node
    with_uuid_model do |model|
      root1 = model.create!
      root2 = model.create!
      child = model.create!(parent: root1)

      assert_equal [root1.id], child.ancestor_ids

      child.parent = root2
      child.save!

      assert_equal [root2.id], child.ancestor_ids
      assert_equal root2.id, child.parent_id
    end
  end

  def test_descendants_and_ancestors
    with_uuid_model do |model|
      root = model.create!
      child = model.create!(parent: root)
      grandchild = model.create!(parent: child)

      assert_equal [child.id, grandchild.id].sort, root.descendant_ids.sort
      assert_equal [root.id, child.id].sort, grandchild.ancestor_ids.sort
      assert grandchild.ancestor_ids.all? { |id| id.is_a?(String) }
    end
  end

  def test_predicates
    with_uuid_model do |model|
      root = model.create!
      child = model.create!(parent: root)

      assert root.root?
      refute root.has_parent?
      assert child.has_parent?
      assert child.child_of?(root)
      assert root.parent_of?(child)
      assert root.ancestor_of?(child)
      assert child.descendant_of?(root)
    end
  end

  def test_orphan_rootify
    with_uuid_model(orphan_strategy: :rootify) do |model|
      root = model.create!
      child = model.create!(parent: root)
      grandchild = model.create!(parent: child)

      child.destroy

      grandchild.reload
      assert_equal [], grandchild.ancestor_ids, "grandchild should be rootified"
    end
  end

  def test_arrange
    with_uuid_model do |model|
      root1 = model.create!
      root2 = model.create!
      model.create!(parent: root1)
      model.create!(parent: root2)

      arranged = model.arrange
      assert arranged.is_a?(Hash)
      assert_equal 2, arranged.keys.size
    end
  end

  def test_integrity_check
    with_uuid_model do |model|
      root = model.create!
      child = model.create!(parent: root)
      model.create!(parent: child)

      assert_nothing_raised do
        model.check_ancestry_integrity!
      end
    end
  end
end
