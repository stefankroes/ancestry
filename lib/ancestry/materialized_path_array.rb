# frozen_string_literal: true

module Ancestry
  # store ancestry as integer array (PostgreSQL only)
  # root: a=[],id=1    children=a||[id] == [1]
  # 3:    a=[1,2],id=3  children=a||[id] == [1,2,3]
  class MaterializedPathArray
    extend Ancestry::Adapter

    def self.root
      []
    end

    def self.generate(ancestor_ids)
      ancestor_ids.presence || root
    end

    def self.parse(obj)
      arr = obj.presence || []
      arr.map(&:to_s)
    end

    def self.parse_integer(obj)
      obj.presence || []
    end

    def self.child_ancestry_value(ancestry_value, id)
      (ancestry_value.presence || []) + [id]
    end

    # Build ARRAY[...] literal with proper quoting and cast for the given values
    def self.array_literal(values)
      if values.first.is_a?(Integer)
        "ARRAY[#{values.join(',')}]::integer[]"
      else
        "ARRAY[#{values.map { |v| "'#{v}'" }.join(',')}]::varchar[]"
      end
    end

    def self.roots_condition(attr)
      attr.eq(root)
    end

    def self.leaves_condition(attr, child_ancestry_sql)
      child_table = Arel::Table.new(attr.relation.name, as: 'c')
      subquery = child_table.where(child_table[attr.name].eq(Arel.sql(child_ancestry_sql))).project(1)
      Arel::Nodes::Not.new(Arel::Nodes::Exists.new(subquery.ast))
    end

    def self.children_condition(attr, child_ancestry)
      attr.eq(child_ancestry)
    end

    def self.siblings_condition(attr, ancestry_value)
      attr.eq(ancestry_value)
    end

    # Arel condition: descendants have ancestry starting with child_ancestry prefix
    # Uses slice comparison (ancestry[1:N] = ARRAY[...]) for correct prefix matching.
    # @> containment is faster (GIN-indexable) but order-independent — it returns
    # incorrect results during cascading moves when ancestry is being rewritten
    # (same root cause as the stale ancestry bug #735/#739).
    def self.descendants_condition(attr, child_ancestry)
      table_name = attr.relation.name
      column_name = attr.name
      col = "#{table_name}.#{column_name}"
      len = child_ancestry.size
      Arel.sql("#{col}[1:#{len}] = #{array_literal(child_ancestry)}")
    end

    # Arel condition: indirects (descendants excluding direct children)
    def self.indirects_condition(attr, child_ancestry)
      table_name = attr.relation.name
      column_name = attr.name
      col = "#{table_name}.#{column_name}"
      len = child_ancestry.size
      Arel.sql("#{col}[1:#{len}] = #{array_literal(child_ancestry)} AND array_length(#{col}, 1) > #{len}")
    end

    # SQL to replace old ancestry prefix with new ancestry prefix in descendants
    #
    # Note: blank branches are currently unreachable — the only caller
    # (update_descendants_with_new_ancestry_sql) passes path_ids which always
    # includes self, so old/new ancestry are never blank. Kept for completeness
    # in case SQL orphan strategies use this in the future.
    def self.replace_ancestry_sql(column, old_ancestry, new_ancestry, _klass)
      old_len = old_ancestry.size
      if old_ancestry.empty? && new_ancestry.empty?
        Arel.sql("#{column}")
      elsif old_ancestry.empty?
        Arel.sql("#{array_literal(new_ancestry)} || #{column}")
      elsif new_ancestry.empty?
        Arel.sql("#{column}[#{old_len + 1}:]")
      else
        Arel.sql("#{array_literal(new_ancestry)} || #{column}[#{old_len + 1}:]")
      end
    end

    def self.child_ancestry_sql(table_name, ancestry_column, primary_key, adapter, integer_pk: true)
      col = "#{table_name}.#{ancestry_column}"
      pk = "#{table_name}.#{primary_key}"
      cast = integer_pk ? "::integer[]" : "::varchar[]"
      "#{col} || ARRAY[#{pk}]#{cast}"
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

    def self.ordered_by_ancestry(arel_column, _adapter)
      Arel::Nodes::Ascending.new(arel_column)
    end

    def self.validation_options(_primary_key_format = nil)
      nil
    end
  end
end
