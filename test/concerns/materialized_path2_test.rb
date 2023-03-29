require_relative '../environment'

class MaterializedPath2Test < ActiveSupport::TestCase
  def test_ancestry_column_mp2
    return unless AncestryTestDatabase.materialized_path2?

    AncestryTestDatabase.with_model do |model|
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
    return unless AncestryTestDatabase.materialized_path2?

    AncestryTestDatabase.with_model do |model|
      node = model.create # assuming id == 1
      ['/3/', '/10/2/', '/9/4/30/', model.ancestry_root].each do |value|
        node.send :write_attribute, model.ancestry_column, value
        assert node.sane_ancestor_ids?
        assert node.valid?
      end
    end
  end

  def test_ancestry_column_validation_fails
    return unless AncestryTestDatabase.materialized_path2?

    AncestryTestDatabase.with_model do |model|
      node = model.create
      ['/a/', '/a/b/', '/-34/'].each do |value|
        node.send :write_attribute, model.ancestry_column, value
        refute node.sane_ancestor_ids?
        refute node.valid?
      end
    end
  end

  def test_ancestry_column_validation_string_key
    return unless AncestryTestDatabase.materialized_path2?

    AncestryTestDatabase.with_model(:id => :string, :primary_key_format => /[a-z]/) do |model|
      node = model.create(:id => 'z')
      ['/a/', '/a/b/', '/a/b/c/', model.ancestry_root].each do |value|
        node.send :write_attribute, model.ancestry_column, value
        assert node.valid?
      end
    end
  end

  def test_ancestry_column_validation_string_key_fails
    return unless AncestryTestDatabase.materialized_path2?

    AncestryTestDatabase.with_model(:id => :string, :primary_key_format => /[a-z]/) do |model|
      node = model.create(:id => 'z')
      ['/1/', '/1/2/', '/a-b/c/'].each do |value|
        node.send :write_attribute, model.ancestry_column, value
        refute node.valid?
      end
    end
  end

  def test_ancestry_validation_exclude_self
    return unless AncestryTestDatabase.materialized_path2?

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
