module Ancestry
  module MaterializedPathPg
    # Update descendants with new ancestry (after update)
    def update_descendants_with_new_ancestry
      # If enabled and node is existing and ancestry was updated and the new ancestry is sane ...
      if !ancestry_callbacks_disabled? && !new_record? && ancestry_changed? && sane_ancestor_ids?
        old_ancestry = generate_ancestry( path_ids_before_last_save )
        new_ancestry = generate_ancestry( path_ids )
        update_clause = [
          "#{self.class.ancestry_column} = regexp_replace(#{self.class.ancestry_column}, '^#{Regexp.escape(old_ancestry)}', '#{new_ancestry}')"
        ]

        if self.class.ancestry_options[:cache_depth] && respond_to?(self.class.ancestry_options[:depth_cache_column])
          update_clause << "#{self.class.ancestry_options[:depth_cache_column]} = length(regexp_replace(regexp_replace(ancestry, '^#{Regexp.escape(old_ancestry)}', '#{new_ancestry}'), '[^#{self.class.ancestry_delimiter}]', '', 'g')) #{self.class.ancestry_options[:ancestry_format] == :materialized_path2 ? '-' : '+'} 1"
        end

        unscoped_descendants_before_save.update_all update_clause.join(', ')
      end
    end
  end
end
