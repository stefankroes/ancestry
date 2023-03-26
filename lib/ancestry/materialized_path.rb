module Ancestry
  # store ancestry as grandparent_id/parent_id
  # root a=nil,id=1   children=id,id/%      == 1, 1/%
  # 3: a=1/2,id=3     children=a/id,a/id/%  == 1/2/3, 1/2/3/%
  module MaterializedPath
    def self.extended(base)
      base.send(:include, InstanceMethods)
    end

    def path_of(object)
      to_node(object).path
    end

    def roots
      where(arel_table[ancestry_column].eq(ancestry_root))
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
      where(t[ancestry_column].matches("#{node.child_ancestry}#{ancestry_delimiter}%", nil, true))
    end

    def descendants_of(object)
      where(descendant_conditions(object))
    end

    def descendants_by_ancestry(ancestry)
      t = arel_table
      t[ancestry_column].matches("#{ancestry}#{ancestry_delimiter}%", nil, true).or(t[ancestry_column].eq(ancestry))
    end

    def descendant_conditions(object)
      node = to_node(object)
      descendants_by_ancestry(node.child_ancestry)
    end

    def descendant_before_last_save_conditions(object)
      node = to_node(object)
      descendants_by_ancestry(node.child_ancestry_before_last_save)
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

    def ancestry_root
      nil
    end

    def ancestry_depth_sql
      @ancestry_depth_sql ||=
        begin
          tmp = %{(LENGTH(#{table_name}.#{ancestry_column}) - LENGTH(REPLACE(#{table_name}.#{ancestry_column},'#{ancestry_delimiter}','')))}
          tmp = tmp + "/#{ancestry_delimiter.size}" if ancestry_delimiter.size > 1
          "(CASE WHEN #{table_name}.#{ancestry_column} IS NULL THEN 0 ELSE 1 + #{tmp} END)"
        end
    end

    def generate_ancestry(ancestor_ids)
      if ancestor_ids.present? && ancestor_ids.any?
        ancestor_ids.join(ancestry_delimiter)
      else
        ancestry_root
      end
    end

    def parse_ancestry_column(obj)
      return [] if obj.nil? || obj == ancestry_root
      obj_ids = obj.split(ancestry_delimiter).delete_if(&:blank?)
      primary_key_is_an_integer? ? obj_ids.map!(&:to_i) : obj_ids
    end

    def ancestry_depth_change(old_value, new_value)
      parse_ancestry_column(new_value).size - parse_ancestry_column(old_value).size
    end

    private

    def ancestry_validation_options(ancestry_primary_key_format)
      {
        format: { with: ancestry_format_regexp(ancestry_primary_key_format) },
        allow_nil: ancestry_nil_allowed?
      }
    end

    def ancestry_nil_allowed?
      true
    end

    def ancestry_format_regexp(primary_key_format)
      /\A#{primary_key_format}(#{Regexp.escape(ancestry_delimiter)}#{primary_key_format})*\z/.freeze
    end

    module InstanceMethods
      # optimization - better to go directly to column and avoid parsing
      def ancestors?
        read_attribute(self.class.ancestry_column) != self.class.ancestry_root
      end
      alias :has_parent? :ancestors?

      def ancestor_ids=(value)
        write_attribute(self.class.ancestry_column, self.class.generate_ancestry(value))
      end

      def ancestor_ids
        self.class.parse_ancestry_column(read_attribute(self.class.ancestry_column))
      end

      def ancestor_ids_in_database
        self.class.parse_ancestry_column(attribute_in_database(self.class.ancestry_column))
      end

      def ancestor_ids_before_last_save
        self.class.parse_ancestry_column(attribute_before_last_save(self.class.ancestry_column))
      end

      def parent_id_in_database
        self.class.parse_ancestry_column(attribute_in_database(self.class.ancestry_column)).last
      end

      def parent_id_before_last_save
        self.class.parse_ancestry_column(attribute_before_last_save(self.class.ancestry_column)).last
      end

      # optimization - better to go directly to column and avoid parsing
      def sibling_of?(node)
        self.read_attribute(self.class.ancestry_column) == node.read_attribute(node.class.ancestry_column)
      end

      # The ancestry value for this record's children
      # This can also be thought of as the ancestry value for the path
      # If this is a new record, it has no id, and it is not valid.
      # NOTE: This could have been called child_ancestry_in_database
      #       the child records were created from the version in the database
      def child_ancestry
        raise Ancestry::AncestryException.new(I18n.t("ancestry.no_child_for_new_record")) if new_record?
        [attribute_in_database(self.class.ancestry_column), id].compact.join(self.class.ancestry_delimiter)
      end

      # The ancestry value for this record's old children
      # Currently used in an after_update via unscoped_descendants_before_last_save
      # to find the old children and bring them along (or to )
      # This is not valid in a new record's after_save.
      def child_ancestry_before_last_save
        if new_record? || respond_to?(:previously_new_record?) && previously_new_record?
          raise Ancestry::AncestryException.new(I18n.t("ancestry.no_child_for_new_record"))
        end
        [attribute_before_last_save(self.class.ancestry_column), id].compact.join(self.class.ancestry_delimiter)
      end
    end
  end
end
