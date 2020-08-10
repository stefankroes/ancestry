require_relative '../environment'

class ValidationsTest < ActiveSupport::TestCase
  def test_ancestry_column_validation
    AncestryTestDatabase.with_model do |model|
      node = model.create
      ['3', '10/2', '1/4/30', nil].each do |value|
        node.send :write_attribute, model.ancestry_column, value
        node.valid?; assert node.errors[model.ancestry_column].blank?
      end
      ['a', 'a/b', '-34'].each do |value|
        node.send :write_attribute, model.ancestry_column, value
        node.valid?; assert !node.errors[model.ancestry_column].blank?
      end
    end
  end

  def test_ancestry_column_validation_alt
    AncestryTestDatabase.with_model(:id => :string, :primary_key_format => /[a-z]/) do |model|
      node = model.create(:id => 'z')
      ['a', 'a/b', 'a/b/c', nil].each do |value|
        node.send :write_attribute, model.ancestry_column, value
        node.valid?; assert node.errors[model.ancestry_column].blank?
      end
      ['1', '1/2', 'a-b/c'].each do |value|
        node.send :write_attribute, model.ancestry_column, value
        node.valid?; assert !node.errors[model.ancestry_column].blank?
      end
    end
  end


  def test_ancestry_validation_exclude_self
    AncestryTestDatabase.with_model do |model|
      parent = model.create!
      child = parent.children.create!
      assert_raise ActiveRecord::RecordInvalid do
        parent.update! :parent => child
      end
    end
  end
end
