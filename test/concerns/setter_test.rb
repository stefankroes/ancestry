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

      # refresh_ancestry + update node + update_descendants
      assert_queries(3, "move leaf via parent=") do
        child.parent = parent2
        child.save!
      end

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

      # find_parent + refresh_ancestry + update node + update_descendants
      assert_queries(4, "move leaf via parent_id=") do
        child.parent_id = parent2.id
        child.save!
      end

      assert_equal child.ancestor_ids, parent2.path_ids
      assert_equal child.parent, parent2

      child.reload
      assert_equal child.ancestor_ids, parent2.path_ids
      assert_equal child.parent, parent2
    end
  end
end
