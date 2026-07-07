# frozen_string_literal: true

require_relative '../environment'

class MaterializedPath2Test < ActiveSupport::TestCase
  def test_ancestry_column_mp2
    AncestryTestDatabase.with_model(ancestry_format: :materialized_path2, ancestry_column: :pedigree) do |model|
      root = model.create!
      node = model.new

      # new node
      assert_equal "/", node.pedigree
      assert_raises(Ancestry::AncestryException) { node.child_ancestry }

      # saved
      node.save!
      assert_equal "/", node.pedigree
      assert_equal "/#{node.id}/", node.child_ancestry

      # changed
      node.ancestor_ids = [root.id]
      assert_equal "/#{root.id}/", node.pedigree
      assert_equal "/", node.pedigree_in_database
      assert_equal "/#{node.id}/", node.child_ancestry

      # changed saved
      node.save!
      assert_equal "/#{root.id}/", node.pedigree
      assert_equal "/#{root.id}/#{node.id}/", node.child_ancestry

      # reloaded
      node.reload
      assert_equal "/#{root.id}/", node.pedigree
      assert_equal "/#{root.id}/#{node.id}/", node.child_ancestry

      # fresh node
      node = model.find(node.id)
      assert_equal "/#{root.id}/", node.pedigree
      assert_equal "/#{root.id}/#{node.id}/", node.child_ancestry
    end
  end

  def test_ancestry_column_validation
    AncestryTestDatabase.with_model(ancestry_format: :materialized_path2, ancestry_column: :pedigree) do |model|
      node = model.create
      ['/3/', '/10/2/', '/9/4/30/', '/'].each do |value|
        node.send :write_attribute, :pedigree, value
        assert node.sane_ancestor_ids?
        assert node.valid?
      end
    end
  end

  def test_ancestry_column_validation_fails
    AncestryTestDatabase.with_model(ancestry_format: :materialized_path2, ancestry_column: :pedigree) do |model|
      node = model.create
      ['/a/', '/a/b/', '/-34/'].each do |value|
        node.send :write_attribute, :pedigree, value
        refute node.sane_ancestor_ids?
        refute node.valid?
      end
    end
  end

  def test_ancestry_column_validation_string_key
    AncestryTestDatabase.with_model(:id => :string, :primary_key_format => /[a-z]/, ancestry_format: :materialized_path2, ancestry_column: :pedigree) do |model|
      node = model.create(:id => 'z')
      ['/a/', '/a/b/', '/a/b/c/', '/'].each do |value|
        node.send :write_attribute, :pedigree, value
        assert node.valid?
      end
    end
  end

  def test_ancestry_column_validation_string_key_fails
    AncestryTestDatabase.with_model(:id => :string, :primary_key_format => /[a-z]/, ancestry_format: :materialized_path2, ancestry_column: :pedigree) do |model|
      node = model.create(:id => 'z')
      ['/1/', '/1/2/', '/a-b/c/'].each do |value|
        node.send :write_attribute, :pedigree, value
        refute node.valid?
      end
    end
  end

  def test_ancestry_validation_exclude_self
    AncestryTestDatabase.with_model(ancestry_format: :materialized_path2, ancestry_column: :pedigree) do |model|
      parent = model.create!
      child = parent.children.create!
      assert_raise ActiveRecord::RecordInvalid do
        parent.parent = child
        refute parent.sane_ancestor_ids?
        parent.save!
      end
    end
  end

  def test_update_strategy_sql
    AncestryTestDatabase.with_model(ancestry_format: :materialized_path2, ancestry_column: :pedigree, depth: 3, width: 1, update_strategy: :sql) do |model, _roots|
      node = model.at_depth(1).first
      root = model.roots.first
      new_root = model.create!

      node.update!(parent: new_root)

      node.descendants.each do |descendant|
        assert descendant.ancestor_ids.include?(new_root.id),
          "descendant #{descendant.id} should include new root"
        refute descendant.ancestor_ids.include?(root.id),
          "descendant #{descendant.id} should not include old root"
      end
    end
  end
end
