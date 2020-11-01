module Ancestry
  module InstanceMethods
    # Update descendants with new ancestry (before save)
    def update_descendants_with_new_ancestry
      # If enabled and node is existing and ancestry was updated
      if !ancestry_callbacks_disabled? && !new_record? && will_save_change_to_ancestor_ids? && sane_ancestor_ids?
        # ... for each descendant ...
        unscoped_descendants.each do |descendant|
          # ... replace old ancestry with new ancestry
          descendant.without_ancestry_callbacks do
            new_ancestor_ids = path_ids + (descendant.ancestor_ids - path_ids_in_database)
            descendant.update_attribute(:ancestor_ids, new_ancestor_ids)
          end
        end
      end
    end

    # Apply orphan strategy (before destroy - no changes)
    def apply_orphan_strategy
      if !ancestry_callbacks_disabled? && !new_record?
        case self.ancestry_base_class.orphan_strategy
        when :rootify # make all children root if orphan strategy is rootify
          unscoped_descendants.each do |descendant|
            descendant.without_ancestry_callbacks do
              descendant.update_attribute :ancestor_ids, descendant.ancestor_ids - path_ids
            end
          end
        when :destroy # destroy all descendants if orphan strategy is destroy
          unscoped_descendants.each do |descendant|
            descendant.without_ancestry_callbacks do
              descendant.destroy
            end
          end
        when :adopt # make child elements of this node, child of its parent
          descendants.each do |descendant|
            descendant.without_ancestry_callbacks do
              descendant.update_attribute :ancestor_ids, descendant.ancestor_ids.delete_if { |x| x == self.id }
            end
          end
        when :restrict # throw an exception if it has children
          raise Ancestry::AncestryException.new(I18n.t("ancestry.cannot_delete_descendants")) unless is_childless?
        end
      end
    end

    # Touch each of this record's ancestors (after save)
    def touch_ancestors_callback
      if !ancestry_callbacks_disabled? && self.ancestry_base_class.touch_ancestors
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
      self.class.increment_counter _counter_cache_column, parent_id
    end

    def decrease_parent_counter_cache
      # @_trigger_destroy_callback comes from activerecord, which makes sure only once decrement when concurrent deletion.
      # but @_trigger_destroy_callback began after rails@5.1.0.alpha.
      # https://github.com/rails/rails/blob/v5.2.0/activerecord/lib/active_record/persistence.rb#L340
      # https://github.com/rails/rails/pull/14735
      # https://github.com/rails/rails/pull/27248
      return if defined?(@_trigger_destroy_callback) && !@_trigger_destroy_callback
      return if ancestry_callbacks_disabled?

      self.class.decrement_counter _counter_cache_column, parent_id
    end

    def parent_id_before_last_save
      ancestor_ids_before_last_save.last
    end

    def update_parent_counter_cache
      return unless saved_change_to_ancestor_ids?

      if parent_id_was = parent_id_before_last_save
        self.class.decrement_counter _counter_cache_column, parent_id_was
      end

      parent_id && self.class.increment_counter(_counter_cache_column, parent_id)
    end

    def _counter_cache_column
      self.ancestry_base_class.counter_cache_column.to_s
    end

    # Ancestors

    # when field is removed, this will end up back at ancestors
    def ancestor_ids?
      ancestor_ids.present?
    end
    alias :ancestors? :ancestor_ids?
    alias :has_parent? :ancestor_ids?
    alias :parent_id? :ancestor_ids?

    def will_save_change_to_ancestor_ids?
      column = self.ancestry_base_class.ancestry_column.to_s
      if ActiveRecord::VERSION::STRING >= '6.1.0'
        # implementation is fine
      elsif ActiveRecord::VERSION::STRING >= '5.1.0'
        # These methods return nil if there are no changes.
        # This was fixed in a refactoring in rails 6.0: https://github.com/rails/rails/pull/35933
        !!(will_save_change_to_attribute?(column) || saved_change_to_attribute?(column))
      else
        changed.include?(column)
      end
    end

    def sane_ancestor_ids?
      valid? || errors[self.ancestry_base_class.ancestry_column].blank?
    end

    def ancestors depth_options = {}
      return self.ancestry_base_class.none unless ancestors?
      self.ancestry_base_class.scope_depth(depth_options, depth).ordered_by_ancestry.ancestors_of(self)
    end

    def path_ids
      ancestor_ids + [id]
    end

    def path_ids_in_database
      ancestor_ids_in_database + [id]
    end

    def path depth_options = {}
      self.ancestry_base_class.scope_depth(depth_options, depth).ordered_by_ancestry.inpath_of(self)
    end

    def depth
      ancestor_ids.size
    end

    def cache_depth
      write_attribute self.ancestry_base_class.depth_cache_column, depth
    end

    def ancestor_of?(node)
      node.ancestor_ids.include?(self.id)
    end

    # Parent

    # currently parent= does not work in after save callbacks
    # assuming that parent hasn't changed
    def parent= parent
      self.ancestor_ids = parent ? parent.path_ids : []
    end

    def parent_id= new_parent_id
      self.parent = new_parent_id.present? ? unscoped_find(new_parent_id) : nil
    end

    def parent_id
      ancestor_ids.last if ancestors?
    end

    def parent
      unscoped_find(parent_id) if ancestors?
    end

    def parent_of?(node)
      self.id == node.parent_id
    end

    # Root

    def root_id
      ancestors? ? ancestor_ids.first : id
    end

    def root
      ancestors? ? unscoped_find(root_id) : self
    end

    def is_root?
      !ancestors?
    end
    alias :root? :is_root?

    def root_of?(node)
      self.id == node.root_id
    end

    # Children

    def children
      self.ancestry_base_class.children_of(self)
    end

    def child_ids
      children.pluck(self.ancestry_base_class.primary_key)
    end

    def has_children?
      self.children.exists?
    end
    alias_method :children?, :has_children?

    def is_childless?
      !has_children?
    end
    alias_method :childless?, :is_childless?

    def child_of?(node)
      self.parent_id == node.id
    end

    # Siblings

    def siblings
      self.ancestry_base_class.siblings_of(self)
    end

    # NOTE: includes self
    def sibling_ids
      siblings.pluck(self.ancestry_base_class.primary_key)
    end

    def has_siblings?
      self.siblings.count > 1
    end
    alias_method :siblings?, :has_siblings?

    def is_only_child?
      !has_siblings?
    end
    alias_method :only_child?, :is_only_child?

    def sibling_of?(node)
      self.ancestor_ids == node.ancestor_ids
    end

    # Descendants

    def descendants depth_options = {}
      self.ancestry_base_class.ordered_by_ancestry.scope_depth(depth_options, depth).descendants_of(self)
    end

    def descendant_ids depth_options = {}
      descendants(depth_options).pluck(self.ancestry_base_class.primary_key)
    end

    def descendant_of?(node)
      ancestor_ids.include?(node.id)
    end

    # Indirects

    def indirects depth_options = {}
      self.ancestry_base_class.ordered_by_ancestry.scope_depth(depth_options, depth).indirects_of(self)
    end

    def indirect_ids depth_options = {}
      indirects(depth_options).pluck(self.ancestry_base_class.primary_key)
    end

    def indirect_of?(node)
      ancestor_ids[0..-2].include?(node.id)
    end

    # Subtree

    def subtree depth_options = {}
      self.ancestry_base_class.ordered_by_ancestry.scope_depth(depth_options, depth).subtree_of(self)
    end

    def subtree_ids depth_options = {}
      subtree(depth_options).pluck(self.ancestry_base_class.primary_key)
    end

    # Callback disabling

    def without_ancestry_callbacks
      @disable_ancestry_callbacks = true
      yield
      @disable_ancestry_callbacks = false
    end

    def ancestry_callbacks_disabled?
      defined?(@disable_ancestry_callbacks) && @disable_ancestry_callbacks
    end

  private
    def unscoped_descendants
      unscoped_where do |scope|
        scope.where self.ancestry_base_class.descendant_conditions(self)
      end
    end

    # works with after save context (hence before_last_save)
    def unscoped_current_and_previous_ancestors
      unscoped_where do |scope|
        scope.where id: (ancestor_ids + ancestor_ids_before_last_save).uniq
      end
    end

    def unscoped_find id
      unscoped_where do |scope|
        scope.find id
      end
    end

    def unscoped_where
      self.ancestry_base_class.unscoped_where do |scope|
        yield scope
      end
    end
  end
end
