require_relative '../environment'

class StiSupportTest < ActiveSupport::TestCase
  def test_sti_support
    AncestryTestDatabase.with_model :extra_columns => {:type => :string} do |model|
      Object.const_set 'Subclass1', Class.new(model)
      Object.const_set 'Subclass2', Class.new(model)

      node1 = Subclass1.create!
      node2 = Subclass2.create! :parent => node1
      node3 = Subclass1.create! :parent => node2
      node4 = Subclass2.create! :parent => node3
      node5 = Subclass1.create! :parent => node4

      model.all.each do |node|
        assert [Subclass1, Subclass2].include?(node.class)
      end

      assert_equal [node2.id, node3.id, node4.id, node5.id], node1.descendants.map(&:id)
      assert_equal [node1.id, node2.id, node3.id, node4.id, node5.id], node1.subtree.map(&:id)
      assert_equal [node1.id, node2.id, node3.id, node4.id], node5.ancestors.map(&:id)
      assert_equal [node1.id, node2.id, node3.id, node4.id, node5.id], node5.path.map(&:id)

      Object.send :remove_const, 'Subclass1'
      Object.send :remove_const, 'Subclass2'
    end
  end

  def test_sti_support_with_from_subclass
    AncestryTestDatabase.with_model :extra_columns => {:type => :string} do |model|
      subclass1 = Object.const_set 'SubclassWithAncestry', Class.new(model)
      subclass1.has_ancestry
      subclass1.create!

      Object.send :remove_const, 'SubclassWithAncestry'
    end
  end
end
