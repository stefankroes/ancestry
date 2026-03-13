# frozen_string_literal: true

module Ancestry
  # store ancestry as grandparent_id/parent_id/
  # root: a="",id=1    children=#{a}#{id}/ == 1/
  # 3:    a=1/2/,id=3   children=#{a}#{id}/ == 1/2/3/
  class MaterializedPath3 < MaterializedPath2
    def self.root(_delimiter)
      ""
    end

    def self.generate(ancestor_ids, delimiter, root)
      if ancestor_ids.present? && ancestor_ids.any?
        "#{ancestor_ids.join(delimiter)}#{delimiter}"
      else
        root
      end
    end

    # SQL expression that extracts the root_id from the ancestry column
    # MP3: ancestry is "" (root, returns id) or "1/2/3/" (root_id=1)
    def self.construct_root_id_sql(table_name, ancestry_column, _delimiter, primary_key, adapter)
      col = table_name ? "#{table_name}.#{ancestry_column}" : ancestry_column.to_s
      pk = table_name ? "#{table_name}.#{primary_key}" : primary_key.to_s
      if %w(mysql mysql2).include?(adapter)
        "CASE WHEN #{col} = '' THEN #{pk} ELSE CAST(SUBSTRING_INDEX(#{col}, '/', 1) AS UNSIGNED) END"
      elsif %w(pg postgresql postgis).include?(adapter)
        "CASE WHEN #{col} = '' THEN #{pk} ELSE CAST(SUBSTR(#{col}, 1, STRPOS(#{col}, '/')-1) AS INTEGER) END"
      else
        "CASE WHEN #{col} = '' THEN #{pk} ELSE CAST(SUBSTR(#{col}, 1, INSTR(#{col}, '/')-1) AS INTEGER) END"
      end
    end

    # SQL expression that extracts the parent_id from the ancestry column
    # MP3: ancestry is "" (root) or "1/2/3/" (parent_id=3)
    def self.construct_parent_id_sql(table_name, ancestry_column, _delimiter, adapter)
      col = table_name ? "#{table_name}.#{ancestry_column}" : ancestry_column.to_s
      if %w(mysql mysql2).include?(adapter)
        "CASE WHEN #{col} = '' THEN NULL ELSE CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(#{col}, '/', -2), '/', 1) AS UNSIGNED) END"
      else
        trimmed = "RTRIM(#{col},'/')"
        "CASE WHEN #{col} = '' THEN NULL ELSE CAST(SUBSTR(#{trimmed}, LENGTH(RTRIM(#{trimmed}, REPLACE(#{trimmed}, '/', ''))) + 1) AS INTEGER) END"
      end
    end

    def self.construct_depth_sql(table_name, ancestry_column, ancestry_delimiter)
      col = table_name ? "#{table_name}.#{ancestry_column}" : ancestry_column.to_s
      tmp = %{(LENGTH(#{col}) - LENGTH(REPLACE(#{col},'#{ancestry_delimiter}','')))}
      tmp += "/#{ancestry_delimiter.size}" if ancestry_delimiter.size > 1
      "(#{tmp})"
    end

    def self.validation_options(primary_key_format, delimiter)
      {
        format: {with: /\A(#{primary_key_format}#{Regexp.escape(delimiter)})*\z/.freeze},
        allow_nil: false
      }
    end
  end
end
