require_relative '../environment'

class ValidationsTest < ActiveSupport::TestCase
  def valid_when_ancestry_column_value_has_correct_format
    AncestryTestDatabase.with_model do |model|
      node = model.create
      ['3', 'A', '10/2', '1/4/30', 'a/b', 'CODE_01/CODE_02/CODE_03', nil].each do |value| #
        node.send :write_attribute, model.ancestry_column, value
        node.valid?; assert node.errors[model.ancestry_column].blank?
      end
    end
  end

  def test_invalid_when_ancetry_column_value_is_malformed
    AncestryTestDatabase.with_model do |model|
      node = model.create
      ['1/3/', '/2/3', '-34', '/54'].each do |value|
        node.send :write_attribute, model.ancestry_column, value
        node.valid?; assert !node.errors[model.ancestry_column].blank?
      end
    end
  end

  def test_validate_ancestry_exclude_self
    AncestryTestDatabase.with_model do |model|
      parent = model.create!
      child = parent.children.create!
      assert_raise ActiveRecord::RecordInvalid do
        parent.update_attributes! :parent => child
      end
    end
  end
end