module Ancestry
  module InstanceMethods
    # Validate that the ancestors don't include itself
    def ancestry_exclude_self
      errors.add(:base, "#{self.class.name.humanize} cannot be a descendant of itself.") if ancestor_ids.include? self.id
    end

    # Update descendants with new ancestry
    def update_descendants_with_new_ancestry
      # If enabled and node is existing and ancestry was updated and the new ancestry is sane ...
      if !ancestry_callbacks_disabled? && !new_record? && ancestry_changed? && sane_ancestry?
        # ... for each descendant ...
        unscoped_descendants.each do |descendant|
          # ... replace old ancestry with new ancestry
          descendant.without_ancestry_callbacks do
            descendant.update_attribute(
              self.ancestry_base_class.ancestry_column,
              descendant.read_attribute(descendant.class.ancestry_column).gsub(
                /^#{self.child_ancestry}/,
                if ancestors? then "#{read_attribute self.class.ancestry_column }/#{id}" else id.to_s end
              )
            )
          end
        end
      end
    end

    # Apply orphan strategy
    def apply_orphan_strategy
      if !ancestry_callbacks_disabled? && !new_record?
        case self.ancestry_base_class.orphan_strategy
        when :rootify # make all children root if orphan strategy is rootify
          unscoped_descendants.each do |descendant|
            descendant.without_ancestry_callbacks do
              new_ancestry = if descendant.ancestry == child_ancestry
                nil
              else
                descendant.ancestry.gsub(/^#{child_ancestry}\//, '')
              end
              descendant.update_attribute descendant.class.ancestry_column, new_ancestry
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
              new_ancestry = descendant.ancestor_ids.delete_if { |x| x == self.id }.join("/")
              # check for empty string if it's then set to nil
              new_ancestry = nil if new_ancestry.empty?
              descendant.update_attribute descendant.class.ancestry_column, new_ancestry || nil
            end
          end
        when :restrict # throw an exception if it has children
          raise Ancestry::AncestryException.new('Cannot delete record because it has descendants.') unless is_childless?
        end
      end
    end

    # Touch each of this record's ancestors
    def touch_ancestors_callback
      if !ancestry_callbacks_disabled? && self.ancestry_base_class.touch_ancestors
        # Touch each of the old *and* new ancestors
        self.class.where(id: (ancestor_ids + ancestor_ids_was).uniq).each do |ancestor|
          ancestor.without_ancestry_callbacks do
            ancestor.touch
          end
        end
      end
    end

    # The ancestry value for this record's children
    def child_ancestry
      # New records cannot have children
      raise Ancestry::AncestryException.new('No child ancestry for new record. Save record before performing tree operations.') if new_record?

      if self.send("#{self.ancestry_base_class.ancestry_column}_was").blank? then id.to_s else "#{self.send "#{self.ancestry_base_class.ancestry_column}_was"}/#{id}" end
    end

    # Ancestors

    def ancestors?
      # ancestor_ids.present?
      read_attribute(self.ancestry_base_class.ancestry_column).present?
    end

    def ancestry_changed?
      changed.include?(self.ancestry_base_class.ancestry_column.to_s)
    end

    def parse_ancestry_column obj
      obj.to_s.split('/').map { |id| cast_primary_key(id) }
    end

    def ancestor_ids
      parse_ancestry_column(read_attribute(self.ancestry_base_class.ancestry_column))
    end

    def ancestor_conditions
      self.ancestry_base_class.ancestor_conditions(self)
    end

    def ancestors depth_options = {}
      self.ancestry_base_class.scope_depth(depth_options, depth).ordered_by_ancestry.where ancestor_conditions
    end

    def ancestor_was_conditions
      {primary_key_with_table => ancestor_ids_was}
    end

    def ancestor_ids_was
      relevant_attributes = if ActiveRecord::VERSION::STRING >= '5.1.0'
        saved_changes.transform_values(&:first)
      else
        changed_attributes
      end

      parse_ancestry_column(relevant_attributes[self.ancestry_base_class.ancestry_column.to_s])
    end

    def path_ids
      ancestor_ids + [id]
    end

    def path_conditions
      self.ancestry_base_class.path_conditions(self)
    end

    def path depth_options = {}
      self.ancestry_base_class.scope_depth(depth_options, depth).ordered_by_ancestry.where path_conditions
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

    def parent= parent
      write_attribute(self.ancestry_base_class.ancestry_column, if parent.nil? then nil else parent.child_ancestry end)
    end

    def parent_id= parent_id
      self.parent = ancestors? ? unscoped_find(parent_id) : nil
    end

    def parent_id
      ancestor_ids.last if ancestors?
    end

    def parent
      unscoped_find(parent_id) if ancestors?
    end

    def parent_id?
      ancestors?
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
      read_attribute(self.ancestry_base_class.ancestry_column).blank?
    end
    alias :root? :is_root?

    def root_of?(node)
      self.id == node.root_id
    end

    # Children

    def child_conditions
      self.ancestry_base_class.child_conditions(self)
    end

    def children
      self.ancestry_base_class.where child_conditions
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

    def sibling_conditions
      self.ancestry_base_class.sibling_conditions(self)
    end

    def siblings
      self.ancestry_base_class.where sibling_conditions
    end

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
      self.ancestry == node.ancestry
    end

    # Descendants

    def descendant_conditions
      self.ancestry_base_class.descendant_conditions(self)
    end

    def descendants depth_options = {}
      self.ancestry_base_class.ordered_by_ancestry.scope_depth(depth_options, depth).where descendant_conditions
    end

    def descendant_ids depth_options = {}
      descendants(depth_options).pluck(self.ancestry_base_class.primary_key)
    end

    def descendant_of?(node)
      ancestor_ids.include?(node.id)
    end

    # Subtree

    def subtree_conditions
      self.ancestry_base_class.subtree_conditions(self)
    end

    def subtree depth_options = {}
      self.ancestry_base_class.ordered_by_ancestry.scope_depth(depth_options, depth).where subtree_conditions
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

    def cast_primary_key(key)
      if [:string, :uuid, :text].include? primary_key_type
        key
      else
        key.to_i
      end
    end

    def primary_key_type
      @primary_key_type ||= column_for_attribute(self.class.primary_key).type
    end

    def unscoped_descendants
      self.ancestry_base_class.unscoped do
        self.ancestry_base_class.where descendant_conditions
      end
    end

    def unscoped_find id
      self.ancestry_base_class.unscoped { self.ancestry_base_class.find(id) }
    end
  end
end
