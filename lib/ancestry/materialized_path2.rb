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
      t = arel_table
      node = to_node(object)
      where(t[ancestry_column].matches("#{node.child_ancestry}%#{ancestry_delimiter}%", nil, true))
    end

    def ordered_by_ancestry(order = nil)
      reorder(Arel::Nodes::Ascending.new(arel_table[ancestry_column]), order)
    end

    def descendants_by_ancestry(ancestry)
      arel_table[ancestry_column].matches("#{ancestry}%", nil, true)
    end

    def ancestry_root
      ancestry_delimiter
    end

    def ancestry_depth_sql
      @ancestry_depth_sql ||=
        begin
          tmp = %{(LENGTH(#{table_name}.#{ancestry_column}) - LENGTH(REPLACE(#{table_name}.#{ancestry_column},'#{ancestry_delimiter}','')))}
          tmp = tmp + "/#{ancestry_delimiter.size}" if ancestry_delimiter.size > 1
          "(#{tmp} -1)"
        end
    end

    def generate_ancestry(ancestor_ids)
      if ancestor_ids.present? && ancestor_ids.any?
        "#{ancestry_delimiter}#{ancestor_ids.join(ancestry_delimiter)}#{ancestry_delimiter}"
      else
        ancestry_root
      end
    end

    private

    def ancestry_nil_allowed?
      false
    end

    def ancestry_format_regexp(primary_key_format)
      /\A#{Regexp.escape(ancestry_delimiter)}(#{primary_key_format}#{Regexp.escape(ancestry_delimiter)})*\z/.freeze
    end

    module InstanceMethods
      # Please see notes for MaterializedPath#child_ancestry
      def child_ancestry
        raise Ancestry::AncestryException.new(I18n.t("ancestry.no_child_for_new_record")) if new_record?
        "#{attribute_in_database(self.class.ancestry_column)}#{id}#{self.class.ancestry_delimiter}"
      end

      # Please see notes for MaterializedPath#child_ancestry_before_last_save
      def child_ancestry_before_last_save
        if new_record? || respond_to?(:previously_new_record?) && previously_new_record?
          raise Ancestry::AncestryException.new(I18n.t("ancestry.no_child_for_new_record"))
        end
        "#{attribute_before_last_save(self.class.ancestry_column)}#{id}#{self.class.ancestry_delimiter}"
      end
    end
  end
end
