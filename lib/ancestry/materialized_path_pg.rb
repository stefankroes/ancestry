# frozen_string_literal: true

module Ancestry
  module MaterializedPathPg
    # Update descendants with new ancestry (after update)
    def update_descendants_with_new_ancestry
      # If enabled and node is existing and ancestry was updated and the new ancestry is sane ...
      # The only way the ancestry could be bad is via `update_attribute` with a bad value
      if !ancestry_callbacks_disabled? && sane_ancestor_ids?
        old_ancestry = self.class.generate_ancestry(path_ids_before_last_save)
        new_ancestry = self.class.generate_ancestry(path_ids)
        update_clause = {
          self.class.ancestry_column => Arel.sql("regexp_replace(#{self.class.ancestry_column}, '^#{Regexp.escape(old_ancestry)}', '#{new_ancestry}')")
        }

        current_time = current_time_from_proper_timezone
        timestamp_attributes_for_update_in_model.each do |column|
          update_clause[column] = current_time
        end

        update_descendants_hook(update_clause, old_ancestry, new_ancestry)
        unscoped_descendants_before_last_save.update_all update_clause
      end
    end

    def update_descendants_hook(update_clause, old_ancestry, new_ancestry)
      if self.class.respond_to?(:depth_cache_column)
        depth_cache_column = self.class.depth_cache_column
        depth_change = self.class.ancestry_depth_change(old_ancestry, new_ancestry)

        if depth_change != 0
          update_clause[depth_cache_column] = Arel.sql("#{depth_cache_column} + #{depth_change}")
        end
      end
      update_clause
    end
  end
end
