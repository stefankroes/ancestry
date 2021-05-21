require_relative '../environment'

class RelationsTest < ActiveSupport::TestCase
  def test_root_found
    AncestryTestDatabase.with_model do |model|
      parent = model.create
      child = model.create!(:ancestor_ids => [parent.id])
      assert_equal(parent, child.root)
    end
  end

  def test_root_not_found
    AncestryTestDatabase.with_model do |model|
      record = model.create
      # setting the parent_id to something not valid
      record.update_attribute(:ancestor_ids, [record.id + 1])
      assert_equal record.root, record
    end
  end

  def test_parent_found
    AncestryTestDatabase.with_model do |model|
      parent = model.create
      child = model.create!(:ancestor_ids => [parent.id])
      assert_equal(parent, child.parent)
    end
  end

  def test_parent_not_found
    AncestryTestDatabase.with_model do |model|
      record = model.create
      # setting the parent_id to something not valid
      record.update_attribute(:ancestor_ids, [record.id + 1])
      assert_nil record.parent
    end
  end
end
