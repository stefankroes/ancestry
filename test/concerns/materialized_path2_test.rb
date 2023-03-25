require_relative '../environment'

class ValidationsTest < ActiveSupport::TestCase
  def test_ancestry_column_validation
    AncestryTestDatabase.with_model do |model|
      node = model.create # assuming id == 1
      if AncestryTestDatabase.materialized_path2?
        vals = ['/3/', '/10/2/', '/9/4/30/', model.ancestry_root]
      else
        vals = ['3', '10/2', '9/4/30', model.ancestry_root]
      end
      vals.each do |value|
        node.send :write_attribute, model.ancestry_column, value
        assert node.sane_ancestor_ids?
        node.valid?
        assert node.errors[model.ancestry_column].blank?
      end
    end
  end

  def test_ancestry_column_validation_fails
    AncestryTestDatabase.with_model do |model|
      node = model.create
      if AncestryTestDatabase.materialized_path2?
        vals = ['/a/', '/a/b/', '/-34/']
      else
        vals = ['a', 'a/b', '-34']
      end
      vals.each do |value|
        node.send :write_attribute, model.ancestry_column, value
        refute node.sane_ancestor_ids?
        node.valid?
        refute node.errors[model.ancestry_column].blank?
      end
    end
  end

  def test_ancestry_column_validation_string_key
    AncestryTestDatabase.with_model(:id => :string, :primary_key_format => /[a-z]/) do |model|
      node = model.create(:id => 'z')
      if AncestryTestDatabase.materialized_path2?
        vals = ['/a/', '/a/b/', '/a/b/c/', model.ancestry_root]
      else
        vals = ['a', 'a/b', 'a/b/c', model.ancestry_root]
      end
      vals.each do |value|
        node.send :write_attribute, model.ancestry_column, value
        node.valid?
        assert node.errors[model.ancestry_column].blank?
      end
    end
  end

  def test_ancestry_column_validation_string_key_fails
    AncestryTestDatabase.with_model(:id => :string, :primary_key_format => /[a-z]/) do |model|
      node = model.create(:id => 'z')
      if AncestryTestDatabase.materialized_path2?
        vals = ['/1/', '/1/2/', '/a-b/c/']
      else
        vals = ['1', '1/2', 'a-b/c']
      end
      vals.each do |value|
        node.send :write_attribute, model.ancestry_column, value
        node.valid?
        refute node.errors[model.ancestry_column].blank?
      end
    end
  end

  def test_ancestry_validation_exclude_self
    AncestryTestDatabase.with_model do |model|
      parent = model.create!
      child = parent.children.create!
      assert_raise ActiveRecord::RecordInvalid do
        parent.parent = child
        refute parent.sane_ancestor_ids?
        parent.save!
      end
    end
  end
end
