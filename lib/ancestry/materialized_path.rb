module Ancestry
  module MaterializedPath
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
      descendant_conditions(object).or(t[primary_key].eq(node.id))
    end

    def sibling_conditions(object)
      t = arel_table
      node = to_node(object)
      t[ancestry_column].eq(node[ancestry_column])
    end
  end
end
