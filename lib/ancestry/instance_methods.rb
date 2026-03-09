# frozen_string_literal: true

module Ancestry
  module InstanceMethods
    # Validate that the ancestors don't include itself
    def ancestry_exclude_self
      errors.add(:base, I18n.t("ancestry.exclude_self", class_name: self.class.model_name.human)) if ancestor_ids.include?(id)
    end

    # Update descendants with new ancestry (after update)
    def update_descendants_with_new_ancestry
      # If enabled and the new ancestry is sane ...
      # The only way the ancestry could be bad is via `update_attribute` with a bad value
      if !ancestry_callbacks_disabled? && sane_ancestor_ids?
        # ... for each descendant ...
        unscoped_descendants_before_last_save.each do |descendant|
          # ... replace old ancestry with new ancestry
          descendant.without_ancestry_callbacks do
            new_ancestor_ids = path_ids + (descendant.ancestor_ids - path_ids_before_last_save)
            descendant.update_attribute(:ancestor_ids, new_ancestor_ids)
          end
        end
      end
    end

    # make all children root if orphan strategy is rootify
    def apply_orphan_strategy_rootify
      return if ancestry_callbacks_disabled? || new_record?

      unscoped_descendants.each do |descendant|
        descendant.without_ancestry_callbacks do
          descendant.update_attribute :ancestor_ids, descendant.ancestor_ids - path_ids
        end
      end
    end

    # destroy all descendants if orphan strategy is destroy
    def apply_orphan_strategy_destroy
      return if ancestry_callbacks_disabled? || new_record?

      unscoped_descendants.ordered_by_ancestry.reverse_order.each do |descendant|
        descendant.without_ancestry_callbacks do
          descendant.destroy
        end
      end
    end

    # make child elements of this node, child of its parent
    def apply_orphan_strategy_adopt
      return if ancestry_callbacks_disabled? || new_record?

      descendants.each do |descendant|
        descendant.without_ancestry_callbacks do
          descendant.update_attribute :ancestor_ids, (descendant.ancestor_ids.delete_if { |x| x == id })
        end
      end
    end

    # throw an exception if it has children
    def apply_orphan_strategy_restrict
      return if ancestry_callbacks_disabled? || new_record?

      raise(Ancestry::AncestryException, I18n.t("ancestry.cannot_delete_descendants")) unless is_childless?
    end

    # Touch each of this record's ancestors (after save)
    def touch_ancestors_callback
      if !ancestry_callbacks_disabled?
        # Touch each of the old *and* new ancestors
        unscoped_current_and_previous_ancestors.each do |ancestor|
          ancestor.without_ancestry_callbacks do
            ancestor.touch
          end
        end
      end
    end

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
