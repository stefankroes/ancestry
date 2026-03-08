# frozen_string_literal: true

module Ancestry
  # store ancestry as /grandparent_id/parent_id/
  # root: a=/,id=1    children=#{a}#{id}/% == /1/%
  # 3:    a=/1/2/,id=3 children=#{a}#{id}/% == /1/2/3/%
  module MaterializedPath2
    def self.root(delimiter)
      delimiter
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
  end
end
