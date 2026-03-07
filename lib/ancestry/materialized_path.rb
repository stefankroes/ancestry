# frozen_string_literal: true

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
      node = to_node(object)
      where(arel_table[ancestry_column].eq(node.child_ancestry))
    end

    def indirects_of(object)
      node = to_node(object)
      where(MaterializedPath.indirects_condition(arel_table[ancestry_column], node.child_ancestry, ancestry_delimiter))
    end

    def descendants_of(object)
      where(descendant_conditions(object))
    end

    def descendants_by_ancestry(ancestry)
      MaterializedPath.descendants_condition(arel_table[ancestry_column], ancestry, ancestry_delimiter)
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
      node = to_node(object)
      descendants_of(node).or(where(arel_table[primary_key].eq(node.id)))
    end

    def siblings_of(object)
      node = to_node(object)
      where(arel_table[ancestry_column].eq(node[ancestry_column].presence))
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

    def child_ancestry_sql
      MaterializedPath.child_ancestry_sql(table_name, ancestry_column, primary_key, ancestry_delimiter, connection.adapter_name.downcase)
    end

    def ancestry_depth_sql
      @ancestry_depth_sql ||= MaterializedPath.construct_depth_sql(table_name, ancestry_column, ancestry_delimiter)
    end

    def generate_ancestry(ancestor_ids)
      MaterializedPath.generate(ancestor_ids, ancestry_delimiter, ancestry_root)
    end

    def parse_ancestry_column(obj)
      MaterializedPath.parse(obj, ancestry_root, ancestry_delimiter, primary_key_is_an_integer?)
    end

    def ancestry_depth_change(old_value, new_value)
      parse_ancestry_column(new_value).size - parse_ancestry_column(old_value).size
    end

    def self.generate(ancestor_ids, delimiter, root)
      if ancestor_ids.present? && ancestor_ids.any?
        ancestor_ids.join(delimiter)
      else
        root
      end
    end

    def self.parse(obj, root, delimiter, integer_pk)
      return [] if obj.nil? || obj == root

      obj_ids = obj.split(delimiter).delete_if(&:blank?)
      integer_pk ? obj_ids.map!(&:to_i) : obj_ids
    end

    def self.child_ancestry_value(ancestry_value, id, delimiter)
      [ancestry_value, id].compact.join(delimiter)
    end

    # Arel condition: descendants have ancestry matching child_ancestry or starting with child_ancestry/
    def self.descendants_condition(attr, child_ancestry, delimiter)
      attr.matches("#{child_ancestry}#{delimiter}%", nil, true).or(attr.eq(child_ancestry))
    end

    # Arel condition: indirects have ancestry matching child_ancestry/*/
    def self.indirects_condition(attr, child_ancestry, delimiter)
      attr.matches("#{child_ancestry}#{delimiter}%", nil, true)
    end

    def concat(*args)
      MaterializedPath.concat(connection.adapter_name.downcase, *args)
    end

    def self.concat(adapter, *args)
      if %w(sqlite sqlite3).include?(adapter)
        args.join('||')
      else
        %{CONCAT(#{args.join(', ')})}
      end
    end

    def self.child_ancestry_sql(table_name, ancestry_column, primary_key, delimiter, adapter)
      pk_sql = concat(adapter, "#{table_name}.#{primary_key}")
      full_sql = concat(adapter, "#{table_name}.#{ancestry_column}", "'#{delimiter}'", "#{table_name}.#{primary_key}")
      %{
        CASE WHEN #{table_name}.#{ancestry_column} IS NULL THEN #{pk_sql}
        ELSE      #{full_sql}
        END
      }
    end

    def self.construct_depth_sql(table_name, ancestry_column, ancestry_delimiter)
      tmp = %{(LENGTH(#{table_name}.#{ancestry_column}) - LENGTH(REPLACE(#{table_name}.#{ancestry_column},'#{ancestry_delimiter}','')))}
      tmp += "/#{ancestry_delimiter.size}" if ancestry_delimiter.size > 1
      "(CASE WHEN #{table_name}.#{ancestry_column} IS NULL THEN 0 ELSE 1 + #{tmp} END)"
    end

    def self.validation_options(primary_key_format, delimiter)
      {
        format: {with: /\A#{primary_key_format}(#{Regexp.escape(delimiter)}#{primary_key_format})*\z/.freeze},
        allow_nil: true
      }
    end

    private

    def ancestry_validation_options(ancestry_primary_key_format)
      MaterializedPath.validation_options(ancestry_primary_key_format, ancestry_delimiter)
    end

    module InstanceMethods
      # optimization - better to go directly to column and avoid parsing
      def ancestors?
        read_attribute(self.class.ancestry_column) != self.class.ancestry_root
      end
      alias has_parent? ancestors?

      def ancestor_ids=(value)
        write_attribute(self.class.ancestry_column, self.class.generate_ancestry(value))
      end

      def ancestor_ids
        MaterializedPath.parse(read_attribute(self.class.ancestry_column), self.class.ancestry_root, self.class.ancestry_delimiter, self.class.primary_key_is_an_integer?)
      end

      def ancestor_ids_in_database
        MaterializedPath.parse(attribute_in_database(self.class.ancestry_column), self.class.ancestry_root, self.class.ancestry_delimiter, self.class.primary_key_is_an_integer?)
      end

      def ancestor_ids_before_last_save
        MaterializedPath.parse(attribute_before_last_save(self.class.ancestry_column), self.class.ancestry_root, self.class.ancestry_delimiter, self.class.primary_key_is_an_integer?)
      end

      def parent_id_in_database
        MaterializedPath.parse(attribute_in_database(self.class.ancestry_column), self.class.ancestry_root, self.class.ancestry_delimiter, self.class.primary_key_is_an_integer?).last
      end

      def parent_id_before_last_save
        MaterializedPath.parse(attribute_before_last_save(self.class.ancestry_column), self.class.ancestry_root, self.class.ancestry_delimiter, self.class.primary_key_is_an_integer?).last
      end

      # optimization - better to go directly to column and avoid parsing
      def sibling_of?(node)
        read_attribute(self.class.ancestry_column) == node.read_attribute(node.class.ancestry_column)
      end

      # The ancestry value for this record's children
      # This can also be thought of as the ancestry value for the path
      # If this is a new record, it has no id, and it is not valid.
      # NOTE: This could have been called child_ancestry_in_database
      #       the child records were created from the version in the database
      def child_ancestry
        raise(Ancestry::AncestryException, I18n.t("ancestry.no_child_for_new_record")) if new_record?

        MaterializedPath.child_ancestry_value(attribute_in_database(self.class.ancestry_column), id, self.class.ancestry_delimiter)
      end

      # The ancestry value for this record's old children
      # Currently used in an after_update via unscoped_descendants_before_last_save
      # to find the old children and bring them along (or to )
      # This is not valid in a new record's after_save.
      def child_ancestry_before_last_save
        if new_record? || (respond_to?(:previously_new_record?) && previously_new_record?)
          raise Ancestry::AncestryException, I18n.t("ancestry.no_child_for_new_record")
        end

        MaterializedPath.child_ancestry_value(attribute_before_last_save(self.class.ancestry_column), id, self.class.ancestry_delimiter)
      end
    end
  end
end
