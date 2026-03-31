# frozen_string_literal: true

module Ancestry
  # store ancestry as grandparent_id/parent_id/
  # root: a="",id=1    children=#{a}#{id}/ == 1/
  # 3:    a=1/2/,id=3   children=#{a}#{id}/ == 1/2/3/
  class MaterializedPath3 < MaterializedPath2
    def self.root
      ""
    end

    # mp3 has trailing delimiter only: "1/2/3/" → split gives ["1", "2", "3"] (clean)
    def self.parse(obj)
      return [] if obj.nil? || obj == root

      obj.split(DELIMITER)
    end

    def self.parse_integer(obj)
      return [] if obj.nil? || obj == root

      obj.split(DELIMITER).map!(&:to_i)
    end

    # trailing delimiter: 1/2/3/
    def self.generate(ancestor_ids)
      if ancestor_ids.present? && ancestor_ids.any?
        "#{ancestor_ids.join(DELIMITER)}/"
      else
        root
      end
    end

    # SQL expression that extracts the root_id from the ancestry column
    # MP3: ancestry is "" (root, returns id) or "1/2/3/" (root_id=1)
    def self.construct_root_id_sql(table_name, ancestry_column, primary_key, adapter)
      col = table_name ? "#{table_name}.#{ancestry_column}" : ancestry_column.to_s
      pk = table_name ? "#{table_name}.#{primary_key}" : primary_key.to_s
      if %w(mysql mysql2 trilogy).include?(adapter)
        "CASE WHEN #{col} = '' THEN #{pk} ELSE CAST(SUBSTRING_INDEX(#{col}, '/', 1) AS UNSIGNED) END"
      elsif %w(pg postgresql postgis).include?(adapter)
        "CASE WHEN #{col} = '' THEN #{pk} ELSE CAST(SUBSTR(#{col}, 1, STRPOS(#{col}, '/')-1) AS INTEGER) END"
      else
        "CASE WHEN #{col} = '' THEN #{pk} ELSE CAST(SUBSTR(#{col}, 1, INSTR(#{col}, '/')-1) AS INTEGER) END"
      end
    end

    # SQL expression that extracts the parent_id from the ancestry column
    # MP3: ancestry is "" (root) or "1/2/3/" (parent_id=3)
    def self.construct_parent_id_sql(table_name, ancestry_column, adapter)
      col = table_name ? "#{table_name}.#{ancestry_column}" : ancestry_column.to_s
      if %w(mysql mysql2 trilogy).include?(adapter)
        "CASE WHEN #{col} = '' THEN NULL ELSE CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(#{col}, '/', -2), '/', 1) AS UNSIGNED) END"
      else
        trimmed = "RTRIM(#{col},'/')"
        "CASE WHEN #{col} = '' THEN NULL ELSE CAST(SUBSTR(#{trimmed}, LENGTH(RTRIM(#{trimmed}, REPLACE(#{trimmed}, '/', ''))) + 1) AS INTEGER) END"
      end
    end

    # delimiter counted: depth = number of delimiters (no -1, no +1 — trailing / matches depth)
    def self.construct_depth_sql(table_name, ancestry_column)
      col = table_name ? "#{table_name}.#{ancestry_column}" : ancestry_column.to_s
      "(LENGTH(#{col}) - LENGTH(REPLACE(#{col},'/','')))"
    end

    # delimiter in regex: /\A(id\/)*\z/
    def self.validation_options(primary_key_format)
      {
        format: {with: /\A(#{primary_key_format}\/)*\z/.freeze},
        allow_nil: false
      }
    end
  end
end
