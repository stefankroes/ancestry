# frozen_string_literal: true

module Ancestry
  # store ancestry as integer array (PostgreSQL only)
  # root: a=[],id=1    children=a||[id] == [1]
  # 3:    a=[1,2],id=3  children=a||[id] == [1,2,3]
  class MaterializedPathArray
    def self.root
      []
    end

    def self.delimiter
      nil
    end

    def self.generate(ancestor_ids)
      ancestor_ids.presence || root
    end

    def self.parse(obj)
      obj.presence || []
    end
    class << self; alias parse_integer parse; end

    def self.child_ancestry_value(ancestry_value, id)
      (ancestry_value.presence || []) + [id]
    end

    # Arel condition: descendants have child_ancestry contained in their ancestry
    # Uses @> (array containment) which is GIN-indexable
    # Ordering is guaranteed by ancestry structure — no positional check needed
    def self.descendants_condition(attr, child_ancestry)
      table_name = attr.relation.name
      column_name = attr.name
      col = "#{table_name}.#{column_name}"
      ids = child_ancestry.join(',')
      Arel.sql("#{col} @> ARRAY[#{ids}]::integer[]")
    end

    # Arel condition: indirects (descendants excluding direct children)
    def self.indirects_condition(attr, child_ancestry)
      table_name = attr.relation.name
      column_name = attr.name
      col = "#{table_name}.#{column_name}"
      ids = child_ancestry.join(',')
      Arel.sql("#{col} @> ARRAY[#{ids}]::integer[] AND array_length(#{col}, 1) > #{child_ancestry.size}")
    end

    # SQL to replace old ancestry prefix with new ancestry prefix in descendants
    def self.replace_ancestry_sql(column, old_ancestry, new_ancestry, _klass)
      old_len = old_ancestry.size
      if old_ancestry.empty? && new_ancestry.empty?
        Arel.sql("#{column}")
      elsif old_ancestry.empty?
        new_ids = new_ancestry.join(',')
        Arel.sql("ARRAY[#{new_ids}]::integer[] || #{column}")
      elsif new_ancestry.empty?
        Arel.sql("#{column}[#{old_len + 1}:]")
      else
        new_ids = new_ancestry.join(',')
        Arel.sql("ARRAY[#{new_ids}]::integer[] || #{column}[#{old_len + 1}:]")
      end
    end

    def self.child_ancestry_sql(table_name, ancestry_column, primary_key, adapter)
      col = "#{table_name}.#{ancestry_column}"
      pk = "#{table_name}.#{primary_key}"
      "#{col} || ARRAY[#{pk}]::integer[]"
    end

    # SQL expression that extracts the root_id from the ancestry column
    # Array: ancestry is '{}' (root, returns id) or '{1,2,3}' (root_id=1)
    def self.construct_root_id_sql(table_name, ancestry_column, primary_key, _adapter)
      col = table_name ? "#{table_name}.#{ancestry_column}" : ancestry_column.to_s
      pk = table_name ? "#{table_name}.#{primary_key}" : primary_key.to_s
      "CASE WHEN #{col} = '{}' THEN #{pk} ELSE #{col}[1] END"
    end

    # SQL expression that extracts the parent_id from the ancestry column
    # Array: ancestry is '{}' (root) or '{1,2,3}' (parent_id=3)
    def self.construct_parent_id_sql(table_name, ancestry_column, adapter)
      col = table_name ? "#{table_name}.#{ancestry_column}" : ancestry_column.to_s
      "CASE WHEN #{col} = '{}' THEN NULL ELSE #{col}[array_length(#{col}, 1)] END"
    end

    # SQL expression for depth: number of elements in ancestry array
    def self.construct_depth_sql(table_name, ancestry_column)
      col = table_name ? "#{table_name}.#{ancestry_column}" : ancestry_column.to_s
      "CASE WHEN #{col} = '{}' THEN 0 ELSE array_length(#{col}, 1) END"
    end

    def self.validation_options(_primary_key_format = nil)
      nil
    end
  end
end
