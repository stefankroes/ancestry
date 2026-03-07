# frozen_string_literal: true

module Ancestry
  module InstanceMethods
    # Validate that the ancestors don't include itself
    def ancestry_exclude_self
      errors.add(:base, I18n.t("ancestry.exclude_self", class_name: self.class.model_name.human)) if ancestor_ids.include?(id)
    end

    # Validate that descendants' depths don't exceed max depth when moving them
    def ancestry_depth_of_descendants
      return if new_record? || (respond_to?(:previously_new_record?) && previously_new_record?)
      return unless self.class.respond_to?(:depth_cache_column) && self.class.depth_cache_column

      column = self.class.depth_cache_column
      validator = self.class.validators_on(column).find do |v|
        v.is_a?(ActiveModel::Validations::NumericalityValidator) &&
          (v.options[:less_than_or_equal_to] || v.options[:less_than])
      end
      return unless validator

      max_depth = validator.options[:less_than_or_equal_to] || (validator.options[:less_than] - 1)

      old_value = attribute_in_database(self.class.ancestry_column)
      new_value = read_attribute(self.class.ancestry_column)
      depth_change = self.class.ancestry_depth_change(old_value, new_value)

      if depth_change > 0
        max_descendant_depth = unscoped_descendants.maximum(column) || attribute_in_database(column) || 0
        if max_descendant_depth + depth_change > max_depth
          errors.add(column, :less_than_or_equal_to, count: max_depth)
        end
      end
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

    # Counter Cache
    def increase_parent_counter_cache
      self.class.ancestry_base_class.increment_counter counter_cache_column, parent_id
    end

    def decrease_parent_counter_cache
      # @_trigger_destroy_callback comes from activerecord, which makes sure only once decrement when concurrent deletion.
      # but @_trigger_destroy_callback began after rails@5.1.0.alpha.
      # https://github.com/rails/rails/blob/v5.2.0/activerecord/lib/active_record/persistence.rb#L340
      # https://github.com/rails/rails/pull/14735
      # https://github.com/rails/rails/pull/27248
      return if defined?(@_trigger_destroy_callback) && !@_trigger_destroy_callback
      return if ancestry_callbacks_disabled?

      self.class.ancestry_base_class.decrement_counter counter_cache_column, parent_id
    end

    def update_parent_counter_cache
      return unless ancestry_changed?

      if (parent_id_was = parent_id_before_last_save)
        self.class.ancestry_base_class.decrement_counter counter_cache_column, parent_id_was
      end

      parent_id && increase_parent_counter_cache
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
