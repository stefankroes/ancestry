# frozen_string_literal: true

module Ancestry
  module InstanceMethods
    # Validate that descendants' depths don't exceed max depth when moving them
    # Called from generated ancestry_depth_of_descendants with baked column names
    def validate_depth_of_descendants(depth_cache_column, depth_change)
      validator = self.class.validators_on(depth_cache_column).find do |v|
        v.is_a?(ActiveModel::Validations::NumericalityValidator) &&
          (v.options[:less_than_or_equal_to] || v.options[:less_than])
      end
      return unless validator

      max_depth = validator.options[:less_than_or_equal_to] || (validator.options[:less_than] - 1)

      if depth_change > 0
        max_descendant_depth = unscoped_descendants.maximum(depth_cache_column) || attribute_in_database(depth_cache_column) || 0
        if max_descendant_depth + depth_change > max_depth
          errors.add(depth_cache_column, :less_than_or_equal_to, count: max_depth)
        end
      end
    end

    # Sync parent cache column and reset association after ancestry change
    def ancestry_sync_parent_cache(parent_cache_column, value, association_name = :parent)
      write_attribute(parent_cache_column, value.last) if parent_cache_column
      association(association_name).reset if association_cached?(association_name)
    end

    # Sync root cache column and reset association after ancestry change
    def ancestry_sync_root_cache(root_cache_column, value, association_name = :root)
      write_attribute(root_cache_column, value.first || id) if root_cache_column
      association(association_name).reset if association_cached?(association_name)
    end

    # Look up parent, using association cache when available
    def ancestry_lookup_parent(association_name = :parent)
      if association(association_name).loaded?
        association(association_name).target
      else
        unscoped_where { |scope| scope.find_by(scope.primary_key => parent_id) }
      end
    end

    # Look up root, using association cache when available
    def ancestry_lookup_root(association_name = :root)
      if association(association_name).loaded?
        association(association_name).target || self
      else
        unscoped_where { |scope| scope.find_by(scope.primary_key => root_id) } || self
      end
    end

    # Add root cache update to SQL update clause for descendants
    def add_root_cache_to_update_clause(update_clause, root_cache_column)
      old_root_id = ancestor_ids_before_last_save.first || id_before_last_save
      new_root_id = ancestor_ids.first || id
      if old_root_id != new_root_id
        update_clause[root_cache_column] = new_root_id
      end
    end

    # Add depth cache update to SQL update clause for descendants
    def add_depth_cache_to_update_clause(update_clause, depth_cache_column, depth_change)
      if depth_change != 0
        update_clause[depth_cache_column] = Arel.sql("#{depth_cache_column} + #{depth_change}")
      end
    end

    # Callback disabling

    def without_ancestry_callbacks
      @disable_ancestry_callbacks = true
      yield
    ensure
      @disable_ancestry_callbacks = false
    end

    def ancestry_callbacks_disabled?
      defined?(@disable_ancestry_callbacks) && @disable_ancestry_callbacks
    end

    private

    def unscoped_descendants
      unscoped_where do |scope|
        scope.where(self.class.ancestry_base_class.descendant_conditions(self))
      end
    end

    def unscoped_descendants_before_last_save
      unscoped_where do |scope|
        scope.where(self.class.ancestry_base_class.descendant_before_last_save_conditions(self))
      end
    end

    # works with after save context (hence before_last_save)
    def unscoped_current_and_previous_ancestors
      unscoped_where do |scope|
        scope.where(scope.primary_key => (ancestor_ids + ancestor_ids_before_last_save).uniq)
      end
    end

    def unscoped_find(id)
      unscoped_where do |scope|
        scope.find(id)
      end
    end

    def unscoped_where(&block)
      self.class.ancestry_base_class.unscoped_where(&block)
    end
  end
end
