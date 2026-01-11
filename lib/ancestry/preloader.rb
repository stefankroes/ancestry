# frozen_string_literal: true

module Ancestry
  module Preloader
    class << self
      # Preload descendants for a collection of records.
      #
      # @param records [Array<ActiveRecord::Base>] Records with has_ancestry
      # @param depth [Integer, nil] Optional maximum depth of descendants to load
      # @return [Array<ActiveRecord::Base>] The input records (for chaining)
      #
      # @example
      #   nodes = Node.where(...)
      #   Ancestry::Preloader.preload_descendants(nodes)
      #   nodes.each { |n| n.preloaded_descendants } # No N+1 queries
      #
      def preload_descendants(records, depth: nil)
        records = Array(records)
        return records if records.empty?

        validate_records!(records)

        model_class = records.first.class.ancestry_base_class
        prefixes = build_prefixes(records)

        # Build and execute single query for all descendants
        all_descendants = fetch_all_descendants(model_class, prefixes.keys, depth, records)

        # Group descendants by their ancestor and cache on instances
        cache_descendants_on_records(records, prefixes, all_descendants, depth)

        records
      end

      private

      def validate_records!(records)
        # Check all records are persisted
        unpersisted = records.find(&:new_record?)
        if unpersisted
          raise Ancestry::AncestryException, "Cannot preload descendants for unpersisted records"
        end

        # Check all records are from the same ancestry base class
        base_classes = records.map { |r| r.class.ancestry_base_class }.uniq
        if base_classes.size > 1
          raise Ancestry::AncestryException, "Cannot preload descendants for records from different models"
        end
      end

      def build_prefixes(records)
        prefixes = {}
        records.each do |record|
          prefix = record.child_ancestry
          prefixes[prefix] ||= []
          prefixes[prefix] << record
        end
        prefixes
      end

      def fetch_all_descendants(model_class, prefixes, depth, records)
        return [] if prefixes.empty?

        # Build combined OR conditions for all prefixes using descendants_by_ancestry
        # (avoiding descendant_conditions which tries to look up the node)
        conditions = prefixes.map do |prefix|
          model_class.descendants_by_ancestry(prefix)
        end

        combined = conditions.reduce { |acc, cond| acc.or(cond) }
        scope = model_class.where(combined)

        # Apply depth filter if specified
        if depth
          max_depth = records.map(&:depth).max + depth
          scope = scope.scope_depth({ to_depth: max_depth }, 0)
        end

        scope.ordered_by_ancestry.to_a
      end

      def cache_descendants_on_records(records, prefixes, all_descendants, depth)
        # Initialize empty arrays for all records
        grouped = Hash.new { |h, k| h[k] = [] }

        # For each descendant, find which records it belongs to
        all_descendants.each do |descendant|
          descendant_ancestry = descendant.read_attribute(descendant.class.ancestry_column)

          prefixes.each do |prefix, ancestor_records|
            if descendant_of_prefix?(descendant_ancestry, prefix, descendant.class)
              ancestor_records.each do |record|
                # Apply depth filter per-record if needed
                if depth.nil? || descendant_within_depth?(descendant, record, depth)
                  grouped[record.object_id] << descendant
                end
              end
            end
          end
        end

        # Cache on each record
        records.each do |record|
          record.instance_variable_set(:@preloaded_descendants, grouped[record.object_id])
        end
      end

      def descendant_of_prefix?(ancestry, prefix, model_class)
        return false if ancestry.nil?

        # For materialized_path2, prefix already ends with delimiter
        # For materialized_path, we need to check for exact match or prefix/
        if model_class.respond_to?(:ancestry_root) && model_class.ancestry_root == model_class.ancestry_delimiter
          # materialized_path2: ancestry starts with prefix
          ancestry.start_with?(prefix)
        else
          # materialized_path: ancestry equals prefix OR starts with prefix/
          ancestry == prefix || ancestry.start_with?("#{prefix}#{model_class.ancestry_delimiter}")
        end
      end

      def descendant_within_depth?(descendant, ancestor, max_depth)
        descendant.depth <= ancestor.depth + max_depth
      end
    end
  end
end
