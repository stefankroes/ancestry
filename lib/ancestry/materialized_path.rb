# frozen_string_literal: true

module Ancestry
  # store ancestry as grandparent_id/parent_id
  # root a=nil,id=1   children=id,id/%      == 1, 1/%
  # 3: a=1/2,id=3     children=a/id,a/id/%  == 1/2/3, 1/2/3/%
  module MaterializedPath
    def self.root(_delimiter)
      nil
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

    # SQL expression that extracts the root_id from the ancestry column
    # MP1: ancestry is NULL (root, returns id) or "1/2/3" (root_id=1)
    def self.construct_root_id_sql(table_name, ancestry_column, _delimiter, primary_key, adapter)
      col = "#{table_name}.#{ancestry_column}"
      pk = "#{table_name}.#{primary_key}"
      if %w(mysql mysql2).include?(adapter)
        "CASE WHEN #{col} IS NULL THEN #{pk} ELSE CAST(SUBSTRING_INDEX(#{col}, '/', 1) AS UNSIGNED) END"
      else
        "CASE WHEN #{col} IS NULL THEN #{pk} ELSE CAST(SUBSTR(#{col}, 1, INSTR(#{col}||'/', '/')-1) AS INTEGER) END"
      end
    end

    # SQL expression that extracts the parent_id from the ancestry column
    # MP1: ancestry is NULL (root) or "1/2/3" (parent_id=3)
    def self.construct_parent_id_sql(table_name, ancestry_column, _delimiter, adapter)
      col = "#{table_name}.#{ancestry_column}"
      if %w(mysql mysql2).include?(adapter)
        "CASE WHEN #{col} IS NULL THEN NULL ELSE CAST(SUBSTRING_INDEX(#{col}, '/', -1) AS UNSIGNED) END"
      else
        "CASE WHEN #{col} IS NULL THEN NULL ELSE CAST(SUBSTR(#{col}, LENGTH(RTRIM(#{col}, REPLACE(#{col}, '/', ''))) + 1) AS INTEGER) END"
      end
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
  end
end
