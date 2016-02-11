require_relative '../environment'

class PrimaryKeyFormatTest < ActiveSupport::TestCase
  def test_ancestry_column_validation_with_custom_primary_key_format
    AncestryTestDatabase.with_model(:primary_key_format => /\A[a-z]-[0-9](\/[a-z]-[0-9])*\Z/) do |model|
      node = model.create
      ['a-1', 'b-2', 'z-9', 'a-1/b-2', 'a-1/b-2/c-4', nil].each do |value|
        node.send :write_attribute, model.ancestry_column, value
        node.valid?; assert node.errors[model.ancestry_column].blank?
      end
      ['a-1/b-2/', '/b-3/z-9', '/y-1', '1', '1/z-9', 'A-1', '1-1', 'a-12'].each do |value|
        node.send :write_attribute, model.ancestry_column, value
        node.valid?; assert !node.errors[model.ancestry_column].blank?
      end
    end
  end
end