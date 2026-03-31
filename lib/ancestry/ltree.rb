# frozen_string_literal: true

module Ancestry
  # store ancestry as grandparent_id.parent_id using PostgreSQL ltree
  # root: a="",id=1    children: a.id == 1
  # 3:    a=1.2,id=3   children: a.id == 1.2.3
  class Ltree < MaterializedPath
    DELIMITER = '.'.freeze

    def self.root
      ""
    end

    def self.delimiter
      DELIMITER
    end

    def self.parse(obj)
      return [] if obj.nil? || obj == root

      obj.split(DELIMITER)
    end

    def self.parse_integer(obj)
      return [] if obj.nil? || obj == root

      obj.split(DELIMITER).map!(&:to_i)
    end

    def self.generate(ancestor_ids)
      if ancestor_ids.present? && ancestor_ids.any?
        ancestor_ids.join(DELIMITER)
      else
        root
      end
    end

    def self.child_ancestry_value(ancestry_value, id)
      ancestry_value.blank? ? id.to_s : "#{ancestry_value}.#{id}"
    end

    # Arel condition: descendants using ltree <@ (descendant-of) operator
    def self.descendants_condition(attr, child_ancestry)
      Arel::Nodes::InfixOperation.new('<@', attr, Arel.sql("'#{child_ancestry}'"))
    end

    # Arel condition: indirects (descendants excluding children)
    def self.indirects_condition(attr, child_ancestry)
      table_name = attr.relation.name
      column_name = attr.name
      desc = descendants_condition(attr, child_ancestry)
      depth_check = Arel.sql("nlevel(#{table_name}.#{column_name}) > nlevel('#{child_ancestry}')")
      Arel::Nodes::And.new([desc, depth_check])
    end

    # SQL to replace old ancestry prefix with new ancestry prefix in descendants
    # Uses ltree || operator which handles dot-joining automatically
    # CASE handles children (ancestry = old_ancestry) where subpath would be out of bounds
    #
    # Note: blank branches are currently unreachable — the only caller
    # (update_descendants_with_new_ancestry_sql) passes path_ids which always
    # includes self, so old/new ancestry are never blank. Kept for completeness
    # in case SQL orphan strategies use this in the future.
    def self.replace_ancestry_sql(column, old_ancestry, new_ancestry, _klass)
      old_len = "nlevel('#{old_ancestry}')"
      if old_ancestry.blank? && new_ancestry.blank?
        Arel.sql("#{column}")
      elsif old_ancestry.blank?
        Arel.sql("text2ltree('#{new_ancestry}') || #{column}")
      elsif new_ancestry.blank?
        Arel.sql("CASE WHEN nlevel(#{column}) = #{old_len} THEN ''::ltree ELSE subpath(#{column}, #{old_len}) END")
      else
        Arel.sql("CASE WHEN nlevel(#{column}) = #{old_len} THEN '#{new_ancestry}'::ltree ELSE text2ltree('#{new_ancestry}') || subpath(#{column}, #{old_len}) END")
      end
    end

    def self.child_ancestry_sql(table_name, ancestry_column, primary_key, adapter, integer_pk: true)
      col = "#{table_name}.#{ancestry_column}"
      pk = "#{table_name}.#{primary_key}"
      "CASE WHEN #{col} = '' THEN #{pk}::text::ltree ELSE #{col} || #{pk}::text::ltree END"
    end

    # SQL expression that extracts the root_id from the ancestry column
    # Ltree: ancestry is "" (root, returns id) or "1.2.3" (root_id=1)
    def self.construct_root_id_sql(table_name, ancestry_column, primary_key, adapter)
      col = table_name ? "#{table_name}.#{ancestry_column}" : ancestry_column.to_s
      pk = table_name ? "#{table_name}.#{primary_key}" : primary_key.to_s
      "CASE WHEN #{col} = '' THEN #{pk} ELSE CAST(subpath(#{col}, 0, 1)::text AS INTEGER) END"
    end

    # SQL expression that extracts the parent_id from the ancestry column
    # Ltree: ancestry is "" (root) or "1.2.3" (parent_id=3)
    def self.construct_parent_id_sql(table_name, ancestry_column, adapter)
      col = table_name ? "#{table_name}.#{ancestry_column}" : ancestry_column.to_s
      "CASE WHEN #{col} = '' THEN NULL ELSE CAST(subpath(#{col}, nlevel(#{col}) - 1, 1)::text AS INTEGER) END"
    end

    def self.construct_depth_sql(table_name, ancestry_column)
      col = table_name ? "#{table_name}.#{ancestry_column}" : ancestry_column.to_s
      "CASE WHEN #{col} = '' THEN 0 ELSE nlevel(#{col}) END"
    end

    def self.ordered_by_ancestry(arel_column, _adapter)
      Arel::Nodes::Ascending.new(arel_column)
    end

    def self.validation_options(_primary_key_format = nil)
      nil
    end
  end
end
