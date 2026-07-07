# frozen_string_literal: true

require_relative '../environment'

class MaterializedPathTest < ActiveSupport::TestCase
  def test_ancestry_column_values
    AncestryTestDatabase.with_model(ancestry_format: :materialized_path, ancestry_column: :lineage) do |model|
      root = model.create!
      node = model.new

      # new node
      assert_nil node.lineage
      assert_raises(Ancestry::AncestryException) { node.child_ancestry }

      # saved
      node.save!
      assert_nil node.lineage
      assert_equal node.id.to_s, node.child_ancestry

      # changed
      node.ancestor_ids = [root.id]
      assert_equal root.id.to_s, node.lineage
      assert_nil node.lineage_in_database
      assert_equal node.id.to_s, node.child_ancestry

      # changed saved
      node.save!
      assert_equal root.id.to_s, node.lineage
      assert_equal "#{root.id}/#{node.id}", node.child_ancestry

      # reloaded
      node.reload
      assert_equal root.id.to_s, node.lineage
      assert_equal "#{root.id}/#{node.id}", node.child_ancestry

      # fresh node
      node = model.find(node.id)
      assert_equal root.id.to_s, node.lineage
      assert_equal "#{root.id}/#{node.id}", node.child_ancestry
    end
  end

  def test_ancestry_column_validation
    AncestryTestDatabase.with_model(ancestry_format: :materialized_path, ancestry_column: :lineage) do |model|
      node = model.create
      ['3', '10/2', '9/4/30', nil].each do |value|
        node.send :write_attribute, :lineage, value
        assert node.sane_ancestor_ids?
        assert node.valid?
      end
    end
  end

  def test_ancestry_column_validation_fails
    AncestryTestDatabase.with_model(ancestry_format: :materialized_path, ancestry_column: :lineage) do |model|
      node = model.create
      ['a', 'a/b', '-34'].each do |value|
        node.send :write_attribute, :lineage, value
        refute node.sane_ancestor_ids?
        refute node.valid?
      end
    end
  end

  def test_ancestry_column_validation_string_key
    AncestryTestDatabase.with_model(:id => :string, :primary_key_format => /[a-z]/, ancestry_format: :materialized_path, ancestry_column: :lineage) do |model|
      node = model.create(:id => 'z')
      ['a', 'a/b', 'a/b/c', nil].each do |value|
        node.send :write_attribute, :lineage, value
        assert node.sane_ancestor_ids?
        assert node.valid?
      end
    end
  end

  def test_ancestry_column_validation_string_key_fails
    AncestryTestDatabase.with_model(:id => :string, :primary_key_format => /[a-z]/, ancestry_format: :materialized_path, ancestry_column: :lineage) do |model|
      node = model.create(:id => 'z')
      ['1', '1/2', 'a-b/c'].each do |value|
        node.send :write_attribute, :lineage, value
        refute node.sane_ancestor_ids?
        refute node.valid?
      end
    end
  end

  def test_ancestry_validation_exclude_self
    AncestryTestDatabase.with_model(ancestry_format: :materialized_path, ancestry_column: :lineage) do |model|
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
