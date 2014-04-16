require File.expand_path('../../environment', __FILE__)

class StiSupportTest < ActiveSupport::TestCase
  def test_sti_support
    AncestryTestDatabase.with_model :extra_columns => {:type => :string} do |model|
      subclass1 = Object.const_set 'Subclass1', Class.new(model)
      (class << subclass1; self; end).send :define_method, :model_name do; Struct.new(:human, :underscore).new 'Subclass1', 'subclass1'; end
      subclass2 = Object.const_set 'Subclass2', Class.new(model)
      (class << subclass2; self; end).send :define_method, :model_name do; Struct.new(:human, :underscore).new 'Subclass1', 'subclass1'; end

      node1 = subclass1.create!
      node2 = subclass2.create! :parent => node1
      node3 = subclass1.create! :parent => node2
      node4 = subclass2.create! :parent => node3
      node5 = subclass1.create! :parent => node4

      model.all.each do |node|
        assert [subclass1, subclass2].include?(node.class)
      end

      assert_equal [node2.id, node3.id, node4.id, node5.id], node1.descendants.map(&:id)
      assert_equal [node1.id, node2.id, node3.id, node4.id, node5.id], node1.subtree.map(&:id)
      assert_equal [node1.id, node2.id, node3.id, node4.id], node5.ancestors.map(&:id)
      assert_equal [node1.id, node2.id, node3.id, node4.id, node5.id], node5.path.map(&:id)
    end
  end

  def test_sti_support_with_from_subclass
    AncestryTestDatabase.with_model :extra_columns => {:type => :string} do |model|
      subclass1 = Object.const_set 'SubclassWithAncestry', Class.new(model)

      subclass1.has_ancestry

      subclass1.create!
    end
  end
end