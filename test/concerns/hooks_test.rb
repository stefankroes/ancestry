# frozen_string_literal: true

require_relative '../environment'

class ArrangementTest < ActiveSupport::TestCase
  # https://github.com/stefankroes/ancestry/issues/267
  def test_has_ancestry_in_after_save
    AncestryTestDatabase.with_model(
      :orphan_strategy => :adopt,
      :extra_columns => {:name => :string, :name_path => :string}
    ) do |model|

      model.class_eval do
        before_save :before_save_hook

        def before_save_hook
          self.name_path = parent ? "#{parent.name_path}/#{name}" : name
          nil
        end
      end

      m1 = model.create!(:name => "parent")
      m2 = model.create(:parent => m1, :name => "child")
      m3 = model.create(:parent_id => m2.id, :name => "grandchild")
      assert_equal("parent", m1.reload.name_path)
      assert_equal("parent/child", m2.reload.name_path)
      assert_equal("parent/child/grandchild", m3.reload.name_path)

      m2.destroy
      m3.reload
      assert_equal([m1.id, m3.id], m3.path_ids)
      assert_equal("parent/grandchild", m3.name_path)
    end
  end

  def test_update_descendants_with_changed_parent_value
    AncestryTestDatabase.with_model(
      extra_columns: { name: :string, name_path: :string }
    ) do |model|

      model.class_eval do
        before_save :update_name_path
        # this example will only work if the name field is unique across all levels
        validates :name, :uniqueness => {case_sensitive: false}

        def update_name_path
          self.name_path = [parent&.name_path, name].compact.join('/')
        end

        def update_descendants_hook(descendants_clause, old_ancestry, new_ancestry)
          super
          # Using REPLACE since it is mysql(binary) and sqlite3 friendly.
          #
          # REGEXP_REPLACE supports an anchor, so it avoids partial matches like 11/21 matching 1/2
          # Introducing leading slashes (e.g.: materialized_path2 or /name/name2/) avoids partial matches

          # avoid SQL injection
          quoted_before = ActiveRecord::Base.connection.quote(name_path_before_last_save)
          quoted_after = ActiveRecord::Base.connection.quote(name_path)

          descendants_clause["name_path"] = Arel.sql("REPLACE(name_path, #{quoted_before}, #{quoted_after})")
        end
      end

      m1 = model.create!(name: "parent")
      m2 = model.create(parent: m1, name: "child")
      m3 = model.create(parent: m2, name: "grandchild")
      m4 = model.create(parent: m3, name: "grandchild's grand")
      assert_equal([m1.id], m2.ancestor_ids)
      assert_equal("parent", m1.reload.name_path)
      assert_equal("parent/child", m2.reload.name_path)
      assert_equal("parent/child/grandchild", m3.reload.name_path)
      assert_equal("parent/child/grandchild/grandchild's grand", m4.reload.name_path)

      m5 = model.create!(name: "changed")

      m2.update!(parent_id: m5.id)
      assert_equal("changed", m5.reload.name_path)
      assert_equal([m5.id], m2.reload.ancestor_ids)
      assert_equal("changed/child", m2.reload.name_path)
      assert_equal([m5.id,m2.id], m3.reload.ancestor_ids)
      assert_equal("changed/child/grandchild", m3.reload.name_path)
      assert_equal([m5.id,m2.id,m3.id], m4.reload.ancestor_ids)
      assert_equal("changed/child/grandchild/grandchild's grand", m4.reload.name_path)
    end
  end

  def test_has_ancestry_detects_changes_in_after_save
    AncestryTestDatabase.with_model(:extra_columns => {:name => :string, :name_path => :string}) do |model|
      model.class_eval do
        after_save :after_hook
        attr_accessor :modified

        def after_hook
          @modified = ancestry_changed?
          nil
        end
      end

      m1 = model.create!(:name => "parent")
      m2 = m1.children.create!(:name => "child")
      m1.modified = m2.modified = nil

      m2.update(parent: nil)

      assert_nil m1.modified, "hook called on record not changed"
      assert m2.modified
    end
  end

  def test_has_ancestry_detects_changes_in_before_save
    AncestryTestDatabase.with_model(:extra_columns => {:name => :string, :name_path => :string}) do |model|
      model.class_eval do
        before_save :before_hook
        attr_accessor :modified

        def before_hook
          @modified = ancestry_changed?
          nil
        end
      end

      m1 = model.create!(:name => "parent")
      m2 = m1.children.create!(:name => "child")
      m1.modified = m2.modified = nil

      m2.update!(parent: nil)

      assert_nil m1.modified, "hook called on record not changed"
      assert m2.modified
    end
  end

  # see f94b22ba https://github.com/stefankroes/ancestry/pull/263
  def test_node_creation_in_after_commit
    AncestryTestDatabase.with_model do |model|
      children=[]
      model.instance_eval do
        attr_accessor :idx
        self.after_commit do
          children << self.children.create!(:idx => self.idx - 1) if self.idx > 0
        end
      end
      model.create!(:idx => 3)
      assert_equal [1,2,3], children.first.ancestor_ids
    end
  end
end
