module Ancestry
  # store ancestry as grandparent_id/parent_id
  # root a=nil,id=1   children=id,id/%      == 1, 1/%
  # 3: a=1/2,id=3     children=a/id,a/id/%  == 1/2/3, 1/2/3/%
  module MaterializedPath
    BEFORE_LAST_SAVE_SUFFIX = '_before_last_save'.freeze
    IN_DATABASE_SUFFIX = '_in_database'.freeze
    ANCESTRY_DELIMITER='/'.freeze
    ROOT=nil

    def self.extended(base)
      base.send(:include, InstanceMethods)
    end

    def path_of(object)
      to_node(object).path
    end

    def roots
      where(arel_table[ancestry_column].eq(ROOT))
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
      where(t[ancestry_column].eq(node.child_ancestry))
    end

    # indirect = anyone who is a descendant, but not a child
    def indirects_of(object)
      t = arel_table
      node = to_node(object)
      where(t[ancestry_column].matches("#{node.child_ancestry}#{ANCESTRY_DELIMITER}%", nil, true))
    end

    def descendants_of(object)
      node = to_node(object)
      indirects_of(node).or(children_of(node))
    end

    # deprecated
    def descendant_conditions(object)
      t = arel_table
      node = to_node(object)
      t[ancestry_column].matches("#{node.child_ancestry}/%", nil, true).or(t[ancestry_column].eq(node.child_ancestry))
    end

    def subtree_of(object)
      t = arel_table
      node = to_node(object)
      descendants_of(node).or(where(t[primary_key].eq(node.id)))
    end

    def siblings_of(object)
      t = arel_table
      node = to_node(object)
      where(t[ancestry_column].eq(node[ancestry_column].presence))
    end

    def ordered_by_ancestry(order = nil)
      if %w(mysql mysql2 sqlite sqlite3).include?(connection.adapter_name.downcase)
        reorder(arel_table[ancestry_column], order)
      elsif %w(postgresql oracleenhanced).include?(connection.adapter_name.downcase) && ActiveRecord::VERSION::STRING >= "6.1"
        reorder(Arel::Nodes::Ascending.new(arel_table[ancestry_column]).nulls_first, order)
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
      # optimization - better to go directly to column and avoid parsing
      def ancestors?
        read_attribute(self.ancestry_base_class.ancestry_column) != ROOT
      end
      alias :has_parent? :ancestors?

      def ancestor_ids=(value)
        col = self.ancestry_base_class.ancestry_column
        value.present? ? write_attribute(col, generate_ancestry(value)) : write_attribute(col, ROOT)
      end

      def ancestor_ids
        parse_ancestry_column(read_attribute(self.ancestry_base_class.ancestry_column))
      end

      def ancestor_ids_in_database
        parse_ancestry_column(send("#{self.ancestry_base_class.ancestry_column}#{IN_DATABASE_SUFFIX}"))
      end

      def ancestor_ids_before_last_save
        parse_ancestry_column(send("#{self.ancestry_base_class.ancestry_column}#{BEFORE_LAST_SAVE_SUFFIX}"))
      end

      def parent_id_before_last_save
        ancestry_was = send("#{self.ancestry_base_class.ancestry_column}#{BEFORE_LAST_SAVE_SUFFIX}")
        return if ancestry_was == ROOT

        parse_ancestry_column(ancestry_was).last
      end

      # optimization - better to go directly to column and avoid parsing
      def sibling_of?(node)
        self.read_attribute(self.ancestry_base_class.ancestry_column) == node.read_attribute(self.ancestry_base_class.ancestry_column)
      end

      # private (public so class methods can find it)
      # The ancestry value for this record's children (before save)
      # This is technically child_ancestry_was
      def child_ancestry
        # New records cannot have children
        raise Ancestry::AncestryException.new(I18n.t("ancestry.no_child_for_new_record")) if new_record?
        path_was = self.send("#{self.ancestry_base_class.ancestry_column}#{IN_DATABASE_SUFFIX}")
        path_was.blank? ? id.to_s : "#{path_was}#{ANCESTRY_DELIMITER}#{id}"
      end

      def parse_ancestry_column(obj)
        return [] if obj == ROOT
        obj_ids = obj.split(ANCESTRY_DELIMITER)
        self.class.primary_key_is_an_integer? ? obj_ids.map!(&:to_i) : obj_ids
      end

      def generate_ancestry(ancestor_ids)
        ancestor_ids.join(ANCESTRY_DELIMITER)
      end
    end
  end
end
