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

  def test_has_ancestry_detects_changes_in_after_save
    AncestryTestDatabase.with_model(:extra_columns => {:name => :string, :name_path => :string}) do |model|
      model.class_eval do
        after_save :after_hook
        attr_reader :modified

        def after_hook
          @modified = saved_change_to_ancestor_ids?
          nil
        end
      end

      m1 = model.create!(:name => "parent")
      m2 = model.create!(:parent => m1, :name => "child")
      m2.parent = nil
      m2.save!
      assert_equal(false, m1.modified)
      assert_equal(true, m2.modified)
    end
  end

  def test_has_ancestry_detects_changes_in_before_save
    AncestryTestDatabase.with_model(:extra_columns => {:name => :string, :name_path => :string}) do |model|
      model.class_eval do
        before_save :before_hook
        attr_reader :modified

        def before_hook
          @modified = ancestor_ids_changed?
          nil
        end
      end

      m1 = model.create!(:name => "parent")
      m2 = model.create!(:parent => m1, :name => "child")
      m2.parent = nil
      m2.save!
      assert_equal(false, m1.modified)
      assert_equal(true, m2.modified)
    end
  end
end
