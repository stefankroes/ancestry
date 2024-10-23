# frozen_string_literal: true

require_relative '../environment'

class IntegrityCheckingAndRestaurationTest < ActiveSupport::TestCase
  def test_set_parent
    AncestryTestDatabase.with_model do |model|
      model.destroy_all
      parent1 = model.create!
      parent2 = model.create!
      child   = model.create!(:parent => parent1)

      assert_equal child.ancestor_ids, parent1.path_ids

      child.parent = parent2
      assert_equal child.parent_id, parent2.id
      child.save

      assert_equal child.ancestor_ids, parent2.path_ids
      assert_equal child.parent_id, parent2.id

      child.reload
      assert_equal child.ancestor_ids, parent2.path_ids
      assert_equal child.parent_id, parent2.id
    end
  end

  def test_set_parent_id
    AncestryTestDatabase.with_model do |model|
      model.destroy_all
      parent1 = model.create!
      parent2 = model.create!
      child   = model.create!(:parent_id => parent1.id)

      assert_equal child.ancestor_ids, parent1.path_ids

      child.parent_id = parent2.id
      assert_equal child.parent, parent2
      child.save

      assert_equal child.ancestor_ids, parent2.path_ids
      assert_equal child.parent, parent2

      child.reload
      assert_equal child.ancestor_ids, parent2.path_ids
      assert_equal child.parent, parent2
    end
  end
end
