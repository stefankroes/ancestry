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
