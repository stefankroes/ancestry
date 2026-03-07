# frozen_string_literal: true

module Ancestry
  # store ancestry as /grandparent_id/parent_id/
  # root: a=/,id=1    children=#{a}#{id}/% == /1/%
  # 3:    a=/1/2/,id=3 children=#{a}#{id}/% == /1/2/3/%
  module MaterializedPath2
    include MaterializedPath

    def self.extended(base)
      base.send(:include, MaterializedPath::InstanceMethods)
      base.send(:include, InstanceMethods)
    end

    def indirects_of(object)
      node = to_node(object)
      where(MaterializedPath2.indirects_condition(arel_table[ancestry_column], node.child_ancestry, ancestry_delimiter))
    end

    def ordered_by_ancestry(order = nil)
      reorder(Arel::Nodes::Ascending.new(arel_table[ancestry_column]), order)
    end

    def descendants_by_ancestry(ancestry)
      MaterializedPath2.descendants_condition(arel_table[ancestry_column], ancestry, ancestry_delimiter)
    end

    def ancestry_root
      ancestry_delimiter
    end

    def child_ancestry_sql
      MaterializedPath2.child_ancestry_sql(table_name, ancestry_column, primary_key, ancestry_delimiter, connection.adapter_name.downcase)
    end

    def ancestry_depth_sql
      @ancestry_depth_sql ||= MaterializedPath2.construct_depth_sql(table_name, ancestry_column, ancestry_delimiter)
    end

    def generate_ancestry(ancestor_ids)
      MaterializedPath2.generate(ancestor_ids, ancestry_delimiter, ancestry_root)
    end

    def self.generate(ancestor_ids, delimiter, root)
      if ancestor_ids.present? && ancestor_ids.any?
        "#{delimiter}#{ancestor_ids.join(delimiter)}#{delimiter}"
      else
        root
      end
    end

    def self.child_ancestry_value(ancestry_value, id, delimiter)
      "#{ancestry_value}#{id}#{delimiter}"
    end

    def self.child_ancestry_sql(table_name, ancestry_column, primary_key, delimiter, adapter)
      MaterializedPath.concat(adapter, "#{table_name}.#{ancestry_column}", "#{table_name}.#{primary_key}", "'#{delimiter}'")
    end

    # mp2: descendants just use LIKE (trailing delimiter prevents false prefix matches)
    def self.descendants_condition(attr, child_ancestry, _delimiter)
      attr.matches("#{child_ancestry}%", nil, true)
    end

    # mp2: indirects match child_ancestry + at least one more segment
    def self.indirects_condition(attr, child_ancestry, delimiter)
      attr.matches("#{child_ancestry}%#{delimiter}%", nil, true)
    end

    # module method
    def self.construct_depth_sql(table_name, ancestry_column, ancestry_delimiter)
      tmp = %{(LENGTH(#{table_name}.#{ancestry_column}) - LENGTH(REPLACE(#{table_name}.#{ancestry_column},'#{ancestry_delimiter}','')))}
      tmp += "/#{ancestry_delimiter.size}" if ancestry_delimiter.size > 1
      "(#{tmp} -1)"
    end

    def self.validation_options(primary_key_format, delimiter)
      {
        format: {with: /\A#{Regexp.escape(delimiter)}(#{primary_key_format}#{Regexp.escape(delimiter)})*\z/.freeze},
        allow_nil: false
      }
    end

    private

    def ancestry_validation_options(ancestry_primary_key_format)
      MaterializedPath2.validation_options(ancestry_primary_key_format, ancestry_delimiter)
    end

    module InstanceMethods
      # Please see notes for MaterializedPath#child_ancestry
      def child_ancestry
        raise(Ancestry::AncestryException, I18n.t("ancestry.no_child_for_new_record")) if new_record?

        MaterializedPath2.child_ancestry_value(attribute_in_database(self.class.ancestry_column), id, self.class.ancestry_delimiter)
      end

      # Please see notes for MaterializedPath#child_ancestry_before_last_save
      def child_ancestry_before_last_save
        if new_record? || (respond_to?(:previously_new_record?) && previously_new_record?)
          raise(Ancestry::AncestryException, I18n.t("ancestry.no_child_for_new_record"))
        end

        MaterializedPath2.child_ancestry_value(attribute_before_last_save(self.class.ancestry_column), id, self.class.ancestry_delimiter)
      end
    end
  end
end
