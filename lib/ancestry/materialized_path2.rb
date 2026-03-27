# frozen_string_literal: true

module Ancestry
  # store ancestry as /grandparent_id/parent_id/
  # root: a=/,id=1    children=#{a}#{id}/% == /1/%
  # 3:    a=/1/2/,id=3 children=#{a}#{id}/% == /1/2/3/%
  class MaterializedPath2 < MaterializedPath
    def self.root
      DELIMITER
    end

    # mp2 has leading delimiter: "/1/2/3/" → split gives ["", "1", "2", "3"]
    # [1..] skips the leading empty string (2x faster than delete_if(&:blank?))
    def self.parse(obj)
      return [] if obj.nil? || obj == root

      obj.split(DELIMITER)[1..]
    end

    def self.parse_integer(obj)
      return [] if obj.nil? || obj == root

      obj.split(DELIMITER)[1..].map!(&:to_i)
    end

    # delimiter wraps: /1/2/3/
    def self.generate(ancestor_ids)
      if ancestor_ids.present? && ancestor_ids.any?
        "/#{ancestor_ids.join(DELIMITER)}/"
      else
        root
      end
    end

    # trailing delimiter: /1/2/ + 3 + / → /1/2/3/
    def self.child_ancestry_value(ancestry_value, id)
      "#{ancestry_value}#{id}/"
    end

    # trailing delimiter: col || pk || '/'
    def self.child_ancestry_sql(table_name, ancestry_column, primary_key, adapter)
      concat(adapter, "#{table_name}.#{ancestry_column}", "#{table_name}.#{primary_key}", "'/'")
    end

    # mp2: descendants just use LIKE (trailing delimiter prevents false prefix matches)
    def self.descendants_condition(attr, child_ancestry)
      attr.matches("#{child_ancestry}%", nil, true)
    end

    # mp2: indirects match child_ancestry + at least one more /segment/
    def self.indirects_condition(attr, child_ancestry)
      attr.matches("#{child_ancestry}%/%", nil, true)
    end

    # SQL expression that extracts the root_id from the ancestry column
    # MP2: ancestry is "/" (root, returns id) or "/1/2/3/" (root_id=1)
    def self.construct_root_id_sql(table_name, ancestry_column, primary_key, adapter)
      col = table_name ? "#{table_name}.#{ancestry_column}" : ancestry_column.to_s
      pk = table_name ? "#{table_name}.#{primary_key}" : primary_key.to_s
      if %w(mysql mysql2).include?(adapter)
        "CASE WHEN #{col} = '/' THEN #{pk} ELSE CAST(SUBSTRING_INDEX(SUBSTRING(#{col}, 2), '/', 1) AS UNSIGNED) END"
      elsif %w(pg postgresql postgis).include?(adapter)
        "CASE WHEN #{col} = '/' THEN #{pk} ELSE CAST(SUBSTR(#{col}, 2, STRPOS(SUBSTR(#{col},2), '/')-1) AS INTEGER) END"
      else
        "CASE WHEN #{col} = '/' THEN #{pk} ELSE CAST(SUBSTR(#{col}, 2, INSTR(SUBSTR(#{col},2), '/')-1) AS INTEGER) END"
      end
    end

    # SQL expression that extracts the parent_id from the ancestry column
    # MP2: ancestry is "/" (root) or "/1/2/3/" (parent_id=3)
    def self.construct_parent_id_sql(table_name, ancestry_column, adapter)
      col = table_name ? "#{table_name}.#{ancestry_column}" : ancestry_column.to_s
      if %w(mysql mysql2).include?(adapter)
        "CASE WHEN #{col} = '/' THEN NULL ELSE CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(#{col}, '/', -2), '/', 1) AS UNSIGNED) END"
      else
        trimmed = "RTRIM(#{col},'/')"
        "CASE WHEN #{col} = '/' THEN NULL ELSE CAST(SUBSTR(#{trimmed}, LENGTH(RTRIM(#{trimmed}, REPLACE(#{trimmed}, '/', ''))) + 1) AS INTEGER) END"
      end
    end

    # delimiter counted: depth = number of delimiters - 1
    def self.construct_depth_sql(table_name, ancestry_column)
      col = table_name ? "#{table_name}.#{ancestry_column}" : ancestry_column.to_s
      "(LENGTH(#{col}) - LENGTH(REPLACE(#{col},'/','')) -1)"
    end

    # mp2/mp3 roots are NOT NULL — simple ascending sort
    def self.ordered_by_ancestry(arel_column, _adapter)
      Arel::Nodes::Ascending.new(arel_column)
    end

    # delimiter in regex: /\A\/(id\/)*\z/
    def self.validation_options(primary_key_format)
      {
        format: {with: /\A\/(#{primary_key_format}\/)*\z/.freeze},
        allow_nil: false
      }
    end
  end
end
