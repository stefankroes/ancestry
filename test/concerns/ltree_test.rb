# frozen_string_literal: true

require_relative '../environment'

class LtreeTest < ActiveSupport::TestCase
  def test_ancestry_column_ltree
    assert true, "this runs if ltree"
    return unless AncestryTestDatabase.ltree?

    AncestryTestDatabase.with_model do |model|
      root = model.create!
      node = model.new

      # new node (default is "" not nil since ltree column has default)
      assert_ancestry node, ""
      assert_raises(Ancestry::AncestryException) { node.child_ancestry }

      # saved
      node.save!
      assert_ancestry node, "", child: node.id.to_s

      # changed
      node.ancestor_ids = [root.id]
      assert_ancestry node, root.id.to_s, db: "", child: node.id.to_s

      # changed saved
      node.save!
      assert_ancestry node, root.id.to_s, child: "#{root.id}.#{node.id}"

      # reloaded
      node.reload
      assert_ancestry node, root.id.to_s, child: "#{root.id}.#{node.id}"

      # fresh node
      node = model.find(node.id)
      assert_ancestry node, root.id.to_s, child: "#{root.id}.#{node.id}"
    end
  end

  def test_ancestry_validation_exclude_self
    assert true, "this runs if ltree"
    return unless AncestryTestDatabase.ltree?

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
