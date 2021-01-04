require_relative '../environment'

class IntegrityCheckingAndRestaurationTest < ActiveSupport::TestCase
  def test_integrity_checking
    AncestryTestDatabase.with_model :width => 3, :depth => 3 do |model, _roots|
      # Check that there are no errors on a valid tree
      assert_nothing_raised do
        model.check_ancestry_integrity!
      end
      assert_equal 0, model.check_ancestry_integrity!(:report => :list).size
    end

    AncestryTestDatabase.with_model :width => 3, :depth => 3 do |model, roots|
      # Check detection of invalid format for ancestry column
      roots.first.first.update_attribute model.ancestry_column, 'invalid_ancestry'
      assert_raise Ancestry::AncestryIntegrityException do
        model.check_ancestry_integrity!
      end
      assert_equal 1, model.check_ancestry_integrity!(:report => :list).size
    end

    AncestryTestDatabase.with_model :width => 3, :depth => 3 do |model, roots|
      # Check detection of non-existent ancestor
      roots.first.first.update_attribute :ancestor_ids, [35]
      assert_raise Ancestry::AncestryIntegrityException do
        model.check_ancestry_integrity!
      end
      assert_equal 1, model.check_ancestry_integrity!(:report => :list).size
    end

    AncestryTestDatabase.with_model :width => 3, :depth => 3 do |model, roots|
      # Check detection of cyclic ancestry
      node = roots.first.first
      node.update_attribute :ancestor_ids, [node.id]
      assert_raise Ancestry::AncestryIntegrityException do
        model.check_ancestry_integrity!
      end
      assert_equal 1, model.check_ancestry_integrity!(:report => :list).size
    end

    AncestryTestDatabase.with_model do |model|
      # Check detection of conflicting parent id
      model.destroy_all
      model.create!(:ancestor_ids => [model.create!(:ancestor_ids => [model.create!(:ancestor_ids => nil).id]).id])
      assert_raise Ancestry::AncestryIntegrityException do
        model.check_ancestry_integrity!
      end
      assert_equal 1, model.check_ancestry_integrity!(:report => :list).size
    end
  end

  def assert_integrity_restoration model
    assert_raise Ancestry::AncestryIntegrityException do
      model.check_ancestry_integrity!
    end
    model.restore_ancestry_integrity!
    assert_nothing_raised do
      model.check_ancestry_integrity!
    end
    assert model.all.any? {|node| node.ancestry.present? }, "Expected some nodes not to be roots"
    assert_equal model.count, model.roots.collect {|node| node.descendants.count + 1 }.sum
  end

  def test_integrity_restoration
    width, depth = 3, 3
    # Check that integrity is restored for invalid format for ancestry column
    AncestryTestDatabase.with_model :width => width, :depth => depth do |model, roots|
      roots.first.first.update_attribute model.ancestry_column, 'invalid_ancestry'
      assert_integrity_restoration model
    end

    # Check that integrity is restored for non-existent ancestor
    AncestryTestDatabase.with_model :width => width, :depth => depth do |model, roots|
      roots.first.first.update_attribute :ancestor_ids, [35]
      assert_integrity_restoration model
    end

    # Check that integrity is restored for cyclic ancestry
    AncestryTestDatabase.with_model :width => width, :depth => depth do |model, roots|
      node = roots.first.first
      node.update_attribute :ancestor_ids, [node.id]
      assert_integrity_restoration model
    end

    # Check that integrity is restored for conflicting parent id
    AncestryTestDatabase.with_model do |model|
      model.destroy_all
      model.create!(:ancestor_ids => [model.create!(:ancestor_ids => [model.create!(:ancestor_ids => nil).id]).id])
      assert_integrity_restoration model
    end
  end
end
