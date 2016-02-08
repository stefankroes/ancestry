require_relative '../environment'

class ValidationsTest < ActiveSupport::TestCase
  def test_ancestry_column_validation
    AncestryTestDatabase.with_model do |model|
      node = model.create
      ['3', '10/2', '1/4/30', nil].each do |value|
        node.send :write_attribute, model.ancestry_column, value
        node.valid?; assert node.errors[model.ancestry_column].blank?
      end
      ['1/3/', '/2/3', 'a', 'a/b', '-34', '/54'].each do |value|
        node.send :write_attribute, model.ancestry_column, value
        node.valid?; assert !node.errors[model.ancestry_column].blank?
      end
    end
  end

  def test_ancestry_column_validation_with_strings
    AncestryTestDatabase.with_model :primary_key_format => "[A-Z]+" do |model|
      node = model.create
      ['A', 'A/B', 'A/B/C', 'AAA/BB', nil].each do |value|
        node.send :write_attribute, model.ancestry_column, value
        node.valid?; assert node.errors[model.ancestry_column].blank?
      end
      ['A-Z'].each do |value|
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
