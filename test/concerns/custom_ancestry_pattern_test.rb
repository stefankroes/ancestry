require_relative '../environment'

class CustomAncestryPatternTest < ActiveSupport::TestCase
  def test_default_ancestry_pattern
    AncestryTestDatabase.with_model :extra_columns => {:type => :string} do |model|
      assert_equal /\A[0-9]+(\/[0-9]+)*\Z/, model::ANCESTRY_PATTERN
    end
  end

  def test_custom_ancestry_pattern
    AncestryTestDatabase.with_model :extra_columns => {:type => :string} do |model|
      assert_equal /\A[0-9]+(\/[0-9]+)*\Z/, model::ANCESTRY_PATTERN
    end
    assert_equal /\A[\w\-]+(\/[\w\-]+)*\z/, UUIDAncestryTestDatabase::ANCESTRY_PATTERN
  end
end