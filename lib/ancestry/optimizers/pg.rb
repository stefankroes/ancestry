module Ancestry
  module Optimizers
    module Pg
      # Update descendants with new ancestry (before save)
      def update_descendants_with_new_ancestry
        # If enabled and node is existing and ancestry was updated and the new ancestry is sane ...
        if !ancestry_callbacks_disabled? && !new_record? && ancestry_changed? && sane_ancestry?
          ancestry_column = ancestry_base_class.ancestry_column
          old_ancestry = child_ancestry
          new_ancestry = ancestors? ? "#{read_attribute ancestry_column}/#{id}" : id.to_s
          update_clause = [
            "#{ancestry_column} = regexp_replace(#{ancestry_column}, '^#{old_ancestry}', '#{new_ancestry}')"
          ]

          if ancestry_base_class.respond_to?(:depth_cache_column) && respond_to?(ancestry_base_class.depth_cache_column)
            depth_cache_column = ancestry_base_class.depth_cache_column.to_s
            update_clause << "#{depth_cache_column} = length(regexp_replace(regexp_replace(ancestry, '^#{old_ancestry}', '#{new_ancestry}'), '\\d', '', 'g')) + 1"
          end

          unscoped_descendants.update_all update_clause.join(', ')
        end
      end
    end
  end
end

Ancestry.optimizer = Ancestry::Optimizers::Pg
