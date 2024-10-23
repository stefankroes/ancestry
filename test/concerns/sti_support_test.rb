# frozen_string_literal: true

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
    AncestryTestDatabase.with_model :ancestry_column => :t1,
                                    :skip_ancestry => true,
                                    :counter_cache => true,
                                    :extra_columns => {:type => :string} do |model|
      subclass1 = Object.const_set 'SubclassWithAncestry', Class.new(model)
      subclass2 = Object.const_set 'SubclassWithAncestry2', Class.new(model)
      subclass1b = Object.const_set 'SubclassOfSubclassWithAncestry', Class.new(subclass1)

      # we are defining it one level below the parent ("model" class)
      subclass1.has_ancestry :ancestry_column => :t1, :counter_cache => true
      subclass2.has_ancestry :ancestry_column => :t1

      # ensure class variables are distinct
      assert subclass1.respond_to?(:counter_cache_column)
      refute subclass2.respond_to?(:counter_cache_column)

      root = subclass1.create!
      # this was the line that was blowing up for this orginal feature
      child = subclass1.create!(:parent => root)
      child2 = subclass1b.create!(:parent => root)

      # counter caches across class lines (going up to parent)

      assert_equal 2, root.reload.children_count

      # children

      assert_equal [child, child2], root.children.order(:id)
      assert_equal root, child.parent

      Object.send :remove_const, 'SubclassWithAncestry'
      Object.send :remove_const, 'SubclassWithAncestry2'
      Object.send :remove_const, 'SubclassOfSubclassWithAncestry'
    end
  end

  def test_sti_support_for_counter_cache
    AncestryTestDatabase.with_model :counter_cache => true, :extra_columns => {:type => :string} do |model|
      # NOTE: had to use subclasses other than Subclass1/Subclass2 from above
      # due to (I think) Rails caching those STI classes and that not getting
      # reset between specs

      Object.const_set 'Subclass3', Class.new(model)
      Object.const_set 'Subclass4', Class.new(model)

      node1 = Subclass3.create!
      node2 = Subclass4.create! :parent => node1
      node3 = Subclass3.create! :parent => node1
      node4 = Subclass4.create! :parent => node3
      node5 = Subclass3.create! :parent => node4

      assert_equal 2, node1.reload.children_count
      assert_equal 0, node2.reload.children_count
      assert_equal 1, node3.reload.children_count
      assert_equal 1, node4.reload.children_count
      assert_equal 0, node5.reload.children_count

      Object.send :remove_const, 'Subclass3'
      Object.send :remove_const, 'Subclass4'
    end
  end
end
