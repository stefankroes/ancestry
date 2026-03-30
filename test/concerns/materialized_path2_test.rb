# frozen_string_literal: true

require_relative '../environment'

class MaterializedPath2Test < ActiveSupport::TestCase
  def test_ancestry_column_mp2
    AncestryTestDatabase.with_model(ancestry_format: :materialized_path2) do |model|
      root = model.create!
      node = model.new

      # new node
      assert_ancestry node, "/", db: nil
      assert_raises(Ancestry::AncestryException) { node.child_ancestry }

      # saved
      node.save!
      assert_ancestry node, "/", child: "/#{node.id}/"

      # changed
      node.ancestor_ids = [root.id]
      assert_ancestry node, "/#{root.id}/", db: "/", child: "/#{node.id}/"

      # changed saved
      node.save!
      assert_ancestry node, "/#{root.id}/", child: "/#{root.id}/#{node.id}/"

      # reloaded
      node.reload
      assert_ancestry node, "/#{root.id}/", child: "/#{root.id}/#{node.id}/"

      # fresh node
      node = model.find(node.id)
      assert_ancestry node, "/#{root.id}/", child: "/#{root.id}/#{node.id}/"
    end
  end

  def test_ancestry_column_validation
    AncestryTestDatabase.with_model(ancestry_format: :materialized_path2) do |model|
      node = model.create # assuming id == 1
      ['/3/', '/10/2/', '/9/4/30/', '/'].each do |value|
        node.send :write_attribute, AncestryTestDatabase.ancestry_column, value
        assert node.sane_ancestor_ids?
        assert node.valid?
      end
    end
  end

  def test_ancestry_column_validation_fails
    AncestryTestDatabase.with_model(ancestry_format: :materialized_path2) do |model|
      node = model.create
      ['/a/', '/a/b/', '/-34/'].each do |value|
        node.send :write_attribute, AncestryTestDatabase.ancestry_column, value
        refute node.sane_ancestor_ids?
        refute node.valid?
      end
    end
  end

  def test_ancestry_column_validation_string_key
    AncestryTestDatabase.with_model(:id => :string, :primary_key_format => /[a-z]/, ancestry_format: :materialized_path2) do |model|
      node = model.create(:id => 'z')
      ['/a/', '/a/b/', '/a/b/c/', '/'].each do |value|
        node.send :write_attribute, AncestryTestDatabase.ancestry_column, value
        assert node.valid?
      end
    end
  end

  def test_ancestry_column_validation_string_key_fails
    AncestryTestDatabase.with_model(:id => :string, :primary_key_format => /[a-z]/, ancestry_format: :materialized_path2) do |model|
      node = model.create(:id => 'z')
      ['/1/', '/1/2/', '/a-b/c/'].each do |value|
        node.send :write_attribute, AncestryTestDatabase.ancestry_column, value
        refute node.valid?
      end
    end
  end

  def test_ancestry_validation_exclude_self
    AncestryTestDatabase.with_model(ancestry_format: :materialized_path2) do |model|
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
    AncestryTestDatabase.with_model(ancestry_format: :materialized_path2, depth: 3, width: 1, update_strategy: :sql) do |model, _roots|
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
