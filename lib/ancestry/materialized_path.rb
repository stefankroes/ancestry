module Ancestry
  module MaterializedPath
    ANCESTRY_DELIMITER='/'.freeze

    def self.extended(base)
      base.send(:include, InstanceMethods)
    end

    def path_of(object)
      to_node(object).path
    end

    def roots
      where(arel_table[ancestry_column].eq(nil))
    end

    def ancestors_of(object)
      t = arel_table
      node = to_node(object)
      where(t[primary_key].in(node.ancestor_ids))
    end

    def inpath_of(object)
      t = arel_table
      node = to_node(object)
      where(t[primary_key].in(node.path_ids))
    end

    def children_of(object)
      t = arel_table
      node = to_node(object)
      where(t[ancestry_column].eq(node.child_ancestor_ids))
    end

    # indirect = anyone who is a descendant, but not a child
    def indirects_of(object)
      t = arel_table
      node = to_node(object)
      where(t[ancestry_column].matches(node.child_ancestor_id_widcard, nil, true))
    end

    def descendants_of(object)
      where(descendant_conditions(object))
    end

    # deprecated
    def descendant_conditions(object)
      t = arel_table
      node = to_node(object)
      t[ancestry_column].matches(node.child_ancestor_id_widcard, nil, true).or(t[ancestry_column].eq(node.child_ancestor_ids))
    end

    def subtree_of(object)
      t = arel_table
      node = to_node(object)
      where(descendant_conditions(node).or(t[primary_key].eq(node.id)))
    end

    def siblings_of(object)
      t = arel_table
      node = to_node(object)
      where(t[ancestry_column].eq(node[ancestry_column].presence))
    end

    def ordered_by_ancestry(order = nil)
      if %w(mysql mysql2 sqlite sqlite3).include?(connection.adapter_name.downcase)
        reorder(arel_table[ancestry_column], order)
      elsif %w(postgresql).include?(connection.adapter_name.downcase) && ActiveRecord::VERSION::STRING >= "6.1"
        reorder(Arel::Nodes::Ascending.new(arel_table[ancestry_column]).nulls_first)
      else
        reorder(
          Arel::Nodes::Ascending.new(Arel::Nodes::NamedFunction.new('COALESCE', [arel_table[ancestry_column], Arel.sql("''")])),
          order
        )
      end
    end

    def ordered_by_ancestry_and(order)
      ordered_by_ancestry(order)
    end

    module InstanceMethods
      # private (public so class methods can find it)
      # The ancestry value for this record's children (before save)
      # This is technically child_ancestor_ids_was
      def child_ancestor_ids
        # New records cannot have children
        raise Ancestry::AncestryException.new(I18n.t("ancestry.no_child_for_new_record")) if new_record?
        ancestor_ids_in_database + [id]
      end

      def child_ancestor_id_widcard
        (child_ancestor_ids + ['%']).join(ANCESTRY_DELIMITER)
      end
    end
  end
end
