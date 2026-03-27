# frozen_string_literal: true

module Ancestry
  # store ancestry as grandparent_id/parent_id
  # root a=nil,id=1   children=id,id/%      == 1, 1/%
  # 3: a=1/2,id=3     children=a/id,a/id/%  == 1/2/3, 1/2/3/%
  class MaterializedPath
    def self.root
      nil
    end

    DELIMITER = '/'.freeze

    def self.delimiter
      DELIMITER
    end

    def self.generate(ancestor_ids)
      if ancestor_ids.present? && ancestor_ids.any?
        ancestor_ids.join(DELIMITER)
      else
        root
      end
    end

    def self.parse(obj)
      return [] if obj.nil? || obj == root

      obj.split(DELIMITER)
    end

    def self.parse_integer(obj)
      return [] if obj.nil? || obj == root

      obj.split(DELIMITER).map!(&:to_i)
    end

    def self.child_ancestry_value(ancestry_value, id)
      [ancestry_value, id].compact.join(DELIMITER)
    end

    # Arel condition: descendants have ancestry matching child_ancestry or starting with child_ancestry/
    def self.descendants_condition(attr, child_ancestry)
      attr.matches("#{child_ancestry}/%", nil, true).or(attr.eq(child_ancestry))
    end

    # Arel condition: indirects have ancestry matching child_ancestry/*/
    def self.indirects_condition(attr, child_ancestry)
      attr.matches("#{child_ancestry}/%", nil, true)
    end

    def self.concat(adapter, *args)
      if %w(sqlite sqlite3).include?(adapter)
        args.join('||')
      else
        %{CONCAT(#{args.join(', ')})}
      end
    end

    # SQL to replace old ancestry prefix with new ancestry prefix in descendants
    def self.replace_ancestry_sql(column, old_ancestry, new_ancestry, klass)
      adapter = klass.connection.adapter_name.downcase
      replace_sql = concat(adapter, "'#{new_ancestry}'", "SUBSTRING(#{column}, #{old_ancestry.length + 1})")
      Arel.sql(replace_sql)
    end

    def self.child_ancestry_sql(table_name, ancestry_column, primary_key, adapter)
      pk_sql = concat(adapter, "#{table_name}.#{primary_key}")
      full_sql = concat(adapter, "#{table_name}.#{ancestry_column}", "'#{DELIMITER}'", "#{table_name}.#{primary_key}")
      %{
        CASE WHEN #{table_name}.#{ancestry_column} IS NULL THEN #{pk_sql}
        ELSE      #{full_sql}
        END
      }
    end

    # SQL expression that extracts the root_id from the ancestry column
    # MP1: ancestry is NULL (root, returns id) or "1/2/3" (root_id=1)
    def self.construct_root_id_sql(table_name, ancestry_column, primary_key, adapter)
      col = table_name ? "#{table_name}.#{ancestry_column}" : ancestry_column.to_s
      pk = table_name ? "#{table_name}.#{primary_key}" : primary_key.to_s
      if %w(mysql mysql2).include?(adapter)
        "CASE WHEN #{col} IS NULL THEN #{pk} ELSE CAST(SUBSTRING_INDEX(#{col}, '/', 1) AS UNSIGNED) END"
      elsif %w(pg postgresql postgis).include?(adapter)
        "CASE WHEN #{col} IS NULL THEN #{pk} ELSE CAST(SUBSTR(#{col}, 1, STRPOS(#{col}||'/', '/')-1) AS INTEGER) END"
      else
        "CASE WHEN #{col} IS NULL THEN #{pk} ELSE CAST(SUBSTR(#{col}, 1, INSTR(#{col}||'/', '/')-1) AS INTEGER) END"
      end
    end

    # SQL expression that extracts the parent_id from the ancestry column
    # MP1: ancestry is NULL (root) or "1/2/3" (parent_id=3)
    def self.construct_parent_id_sql(table_name, ancestry_column, adapter)
      col = table_name ? "#{table_name}.#{ancestry_column}" : ancestry_column.to_s
      if %w(mysql mysql2).include?(adapter)
        "CASE WHEN #{col} IS NULL THEN NULL ELSE CAST(SUBSTRING_INDEX(#{col}, '/', -1) AS UNSIGNED) END"
      else
        "CASE WHEN #{col} IS NULL THEN NULL ELSE CAST(SUBSTR(#{col}, LENGTH(RTRIM(#{col}, REPLACE(#{col}, '/', ''))) + 1) AS INTEGER) END"
      end
    end

    def self.construct_depth_sql(table_name, ancestry_column)
      col = table_name ? "#{table_name}.#{ancestry_column}" : ancestry_column.to_s
      "(CASE WHEN #{col} IS NULL THEN 0 ELSE 1 + (LENGTH(#{col}) - LENGTH(REPLACE(#{col},'#{DELIMITER}',''))) END)"
    end

    def self.validation_options(primary_key_format)
      {
        format: {with: /\A#{primary_key_format}(\/#{primary_key_format})*\z/.freeze},
        allow_nil: true
      }
    end
  end
end
