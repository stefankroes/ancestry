module Ancestry
  # store ancestry as /grandparent_id/parent_id/
  # root: a=/,id=1    children=a.id/% == /1/%
  # 3:    a=/1/2/,id=3 children=a.id/% == /1/2/3/%
  module MaterializedPath2 < MaterializedPath
    def indirects_of(object)
      t = arel_table
      node = to_node(object)
      where(t[ancestry_column].matches("#{node.child_ancestry}%#{ANCESTRY_DELIMITER}%", nil, true))
    end

    def subtree_of(object)
      t = arel_table
      node = to_node(object)
      where(descendant_conditions(node).or(t[primary_key].eq(node.id)))
    end

    def siblings_of(object)
      t = arel_table
      node = to_node(object)
      where(t[ancestry_column].eq(node[ancestry_column]))
    end

    def ordered_by_ancestry(order = nil)
      reorder(Arel::Nodes::Ascending.new(arel_table[ancestry_column]), order)
    end

    # deprecated
    def descendant_conditions(object)
      t = arel_table
      node = to_node(object)
      t[ancestry_column].matches("#{node.child_ancestry}%", nil, true)
    end

    module InstanceMethods
      def child_ancestry
        # New records cannot have children
        raise Ancestry::AncestryException.new('No child ancestry for new record. Save record before performing tree operations.') if new_record?
        path_was = self.send("#{self.ancestry_base_class.ancestry_column}#{IN_DATABASE_SUFFIX}")
        "#{path_was}#{id}#{ANCESTRY_DELIMITER}"
      end

      def parse_ancestry_column(obj)
        return [] if obj == ROOT
        obj_ids = obj.split(ANCESTRY_DELIMITER).delete_if(&:blank?)
        self.class.primary_key_is_an_integer? ? obj_ids.map!(&:to_i) : obj_ids
      end

      def generate_ancestry(ancestor_ids)
        "#{ANCESTRY_DELIMITER}#{ancestor_ids.join(ANCESTRY_DELIMITER)}#{ANCESTRY_DELIMITER}"
      end
    end
  end
end
