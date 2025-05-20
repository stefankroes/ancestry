# frozen_string_literal: true

module Ancestry
  # Provides automatic preloading of tree relationships when enabled
  module Preloader
    extend ActiveSupport::Concern

    included do
      # Store original methods to call later
      class << self
        alias_method :original_find_by_sql, :find_by_sql
      end
    end

    class_methods do
      # Override find_by_sql to apply preloading when enabled
      def find_by_sql(sql, binds = [], preparable: nil, **kwargs)
        records = original_find_by_sql(sql, binds, preparable: preparable, **kwargs)
        
        # Skip preloading if empty results or preload is not enabled
        return records if records.empty? || !ancestry_preload
        
        # Apply with_tree to preload all relationships
        tree_preloader = records.first.class
        preloaded_records = if tree_preloader.respond_to?(:arrange_nodes)
          tree_preloader.with_tree(records)
        else
          records
        end
        
        # Return the preloaded records
        preloaded_records
      end
    end
  end
end
