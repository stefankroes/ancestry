module Ancestry
  module MaterializedPath
    BEFORE_LAST_SAVE_SUFFIX = '_before_last_save'.freeze
    IN_DATABASE_SUFFIX = '_in_database'.freeze
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
      where(t[ancestry_column].eq(node.child_ancestry))
    end

    # indirect = anyone who is a descendant, but not a child
    def indirects_of(object)
      t = arel_table
      node = to_node(object)
      where(t[ancestry_column].matches("#{node.child_ancestry}/%", nil, true))
    end

    def descendants_of(object)
      where(descendant_conditions(object))
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

      # Validates the ancestry, but can also be applied if validation is bypassed to determine if children should be affected
      def sane_ancestry?
        ancestry_value = read_attribute(self.ancestry_base_class.ancestry_column)
        (ancestry_value.nil? || !ancestor_ids.include?(self.id)) && valid?
      end

      # optimization - better to go directly to column and avoid parsing
      def ancestors?
        read_attribute(self.ancestry_base_class.ancestry_column).present?
      end
      alias :has_parent? :ancestors?

      def ancestor_ids=(value)
        col = self.ancestry_base_class.ancestry_column
        value.present? ? write_attribute(col, value.join(ANCESTRY_DELIMITER)) : write_attribute(col, nil)
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
        return unless ancestry_was.present?

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
        path_was.blank? ? id.to_s : "#{path_was}/#{id}"
      end

      private

      def parse_ancestry_column obj
        return [] unless obj
        obj_ids = obj.split(ANCESTRY_DELIMITER)
        self.class.primary_key_is_an_integer? ? obj_ids.map!(&:to_i) : obj_ids
      end
    end
  end
end
