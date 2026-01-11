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
      return unless saved_change_to_attribute?(self.class.ancestry_column)

      if (parent_id_was = parent_id_before_last_save)
        self.class.ancestry_base_class.decrement_counter counter_cache_column, parent_id_was
      end

      parent_id && increase_parent_counter_cache
    end

    # Ancestors

    def has_parent?
      ancestor_ids.present?
    end
    alias ancestors? has_parent?

    def ancestry_changed?
      column = self.class.ancestry_column.to_s
      # These methods return nil if there are no changes.
      # This was fixed in a refactoring in rails 6.0: https://github.com/rails/rails/pull/35933
      !!(will_save_change_to_attribute?(column) || saved_change_to_attribute?(column))
    end

    def sane_ancestor_ids?
      current_context, self.validation_context = validation_context, nil
      errors.clear

      attribute = self.class.ancestry_column
      ancestry_value = send(attribute)
      return true unless ancestry_value

      self.class.validators_on(attribute).each do |validator|
        validator.validate_each(self, attribute, ancestry_value)
      end
      ancestry_exclude_self
      errors.none?
    ensure
      self.validation_context = current_context
    end

    def ancestors(depth_options = {})
      return self.class.ancestry_base_class.none unless has_parent?

      self.class.ancestry_base_class.scope_depth(depth_options, depth).ordered_by_ancestry.ancestors_of(self)
    end

    def path_ids
      ancestor_ids + [id]
    end

    def path_ids_before_last_save
      ancestor_ids_before_last_save + [id]
    end

    def path_ids_in_database
      ancestor_ids_in_database + [id]
    end

    def path(depth_options = {})
      self.class.ancestry_base_class.scope_depth(depth_options, depth).ordered_by_ancestry.inpath_of(self)
    end

    def depth
      ancestor_ids.size
    end

    def cache_depth
      write_attribute self.class.ancestry_base_class.depth_cache_column, depth
    end

    def ancestor_of?(node)
      node.ancestor_ids.include?(id)
    end

    # Parent

    # currently parent= does not work in after save callbacks
    # assuming that parent hasn't changed
    def parent=(parent)
      self.ancestor_ids = parent ? parent.path_ids : []
    end

    def parent_id=(new_parent_id)
      self.parent = new_parent_id.present? ? unscoped_find(new_parent_id) : nil
    end

    def parent_id
      ancestor_ids.last if has_parent?
    end
    alias parent_id? ancestors?

    def parent
      if has_parent?
        unscoped_where do |scope|
          scope.find_by scope.primary_key => parent_id
        end
      end
    end

    def parent_of?(node)
      id == node.parent_id
    end

    # Root

    def root_id
      has_parent? ? ancestor_ids.first : id
    end

    def root
      if has_parent?
        unscoped_where { |scope| scope.find_by(scope.primary_key => root_id) } || self
      else
        self
      end
    end

    def is_root?
      !has_parent?
    end
    alias root? is_root?

    def root_of?(node)
      id == node.root_id
    end

    # Children

    def children
      self.class.ancestry_base_class.children_of(self)
    end

    def child_ids
      children.pluck(self.class.primary_key)
    end

    def has_children?
      children.exists?
    end
    alias_method :children?, :has_children?

    def is_childless?
      !has_children?
    end
    alias_method :childless?, :is_childless?

    def child_of?(node)
      parent_id == node.id
    end

    # Siblings

    def siblings
      self.class.ancestry_base_class.siblings_of(self)
    end

    # NOTE: includes self
    def sibling_ids
      siblings.pluck(self.class.primary_key)
    end

    def has_siblings?
      siblings.where.not(self.class.primary_key => id).exists?
    end
    alias_method :siblings?, :has_siblings?

    def is_only_child?
      !has_siblings?
    end
    alias_method :only_child?, :is_only_child?

    def sibling_of?(node)
      ancestor_ids == node.ancestor_ids
    end

    # Descendants

    def descendants(depth_options = {})
      self.class.ancestry_base_class.ordered_by_ancestry.scope_depth(depth_options, depth).descendants_of(self)
    end

    # Returns preloaded descendants if available, otherwise falls back to a query.
    # Use Ancestry::Preloader.preload_descendants(records) to populate this cache.
    #
    # @return [Array<ActiveRecord::Base>] Descendant records
    def preloaded_descendants
      if defined?(@preloaded_descendants)
        @preloaded_descendants
      else
        descendants.to_a
      end
    end

    def descendant_ids(depth_options = {})
      descendants(depth_options).pluck(self.class.primary_key)
    end

    def descendant_of?(node)
      ancestor_ids.include?(node.id)
    end

    # Indirects

    def indirects(depth_options = {})
      self.class.ancestry_base_class.ordered_by_ancestry.scope_depth(depth_options, depth).indirects_of(self)
    end

    def indirect_ids(depth_options = {})
      indirects(depth_options).pluck(self.class.primary_key)
    end

    def indirect_of?(node)
      ancestor_ids[0..-2].include?(node.id)
    end

    # Subtree

    def subtree(depth_options = {})
      self.class.ancestry_base_class.ordered_by_ancestry.scope_depth(depth_options, depth).subtree_of(self)
    end

    def subtree_ids(depth_options = {})
      subtree(depth_options).pluck(self.class.primary_key)
    end

    def in_subtree_of?(node)
      id == node.id || descendant_of?(node)
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
