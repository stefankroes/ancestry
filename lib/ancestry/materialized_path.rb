module Ancestry
  module MaterializedPath
    def self.extended(base)
      base.validates_format_of base.ancestry_column, :with => Ancestry::ANCESTRY_PATTERN, :allow_nil => true
      base.send(:include, InstanceMethods)
    end

    def root_conditions
      arel_table[ancestry_column].eq(nil)
    end

    def ancestor_conditions(object)
      t = arel_table
      node = to_node(object)
      t[primary_key].in(node.ancestor_ids)
    end

    def path_conditions(object)
      t = arel_table
      node = to_node(object)
      t[primary_key].in(node.path_ids)
    end

    def child_conditions(object)
      t = arel_table
      node = to_node(object)
      t[ancestry_column].eq(node.child_ancestry)
    end

    # indirect = anyone who is a descendant, but not a child
    def indirect_conditions(object)
      t = arel_table
      node = to_node(object)
      # rails has case sensitive matching.
      if ActiveRecord::VERSION::MAJOR >= 5
        t[ancestry_column].matches("#{node.child_ancestry}/%", nil, true)
      else
        t[ancestry_column].matches("#{node.child_ancestry}/%")
      end
    end

    def descendant_conditions(object)
      t = arel_table
      node = to_node(object)
      # rails has case sensitive matching.
      if ActiveRecord::VERSION::MAJOR >= 5
        t[ancestry_column].matches("#{node.child_ancestry}/%", nil, true).or(t[ancestry_column].eq(node.child_ancestry))
      else
        t[ancestry_column].matches("#{node.child_ancestry}/%").or(t[ancestry_column].eq(node.child_ancestry))
      end
    end

    def subtree_conditions(object)
      t = arel_table
      node = to_node(object)
      descendant_conditions(node).or(t[primary_key].eq(node.id))
    end

    def sibling_conditions(object)
      t = arel_table
      node = to_node(object)
      t[ancestry_column].eq(node[ancestry_column])
    end

    module InstanceMethods
      # Validates the ancestry, but can also be applied if validation is bypassed to determine if children should be affected
      def sane_ancestry?
        ancestry_value = read_attribute(self.ancestry_base_class.ancestry_column)
        ancestry_value.nil? || (ancestry_value.to_s =~ Ancestry::ANCESTRY_PATTERN && !ancestor_ids.include?(self.id))
      end
    end
  end
end
