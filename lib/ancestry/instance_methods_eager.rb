# frozen_string_literal: true

module Ancestry
  # Extends instance methods with eager loading capability
  module InstanceMethodsEager
    # Ancestors with eager loading support
    def ancestors(depth_options = {})
      if instance_variable_defined?(:@_eager_loaded_ancestors)
        # Filter by depth if required
        ancestors = instance_variable_get(:@_eager_loaded_ancestors)
        if depth_options.present?
          ancestor_depth = depth
          scope = self.class.ancestry_base_class.scope_depth(depth_options, ancestor_depth)
          ancestor_ids = scope.where(self.class.primary_key => ancestors.map(&:id)).pluck(self.class.primary_key)
          ancestors.select { |ancestor| ancestor_ids.include?(ancestor.id) }
        else
          ancestors
        end
      else
        super
      end
    end

    # Children with eager loading support
    def children
      if instance_variable_defined?(:@_eager_loaded_children)
        instance_variable_get(:@_eager_loaded_children)
      else
        super
      end
    end

    # Parent with eager loading support
    def parent
      if instance_variable_defined?(:@_eager_loaded_parent)
        instance_variable_get(:@_eager_loaded_parent)
      else
        super
      end
    end

    # Siblings with eager loading support
    def siblings
      if instance_variable_defined?(:@_eager_loaded_siblings)
        instance_variable_get(:@_eager_loaded_siblings)
      else
        super
      end
    end

    # Descendants with eager loading support
    def descendants(depth_options = {})
      if instance_variable_defined?(:@_eager_loaded_children)
        descendants = collect_descendants
        
        if depth_options.present?
          # Filter by depth if required
          descendant_depth = depth
          scope = self.class.ancestry_base_class.scope_depth(depth_options, descendant_depth)
          descendant_ids = scope.where(self.class.primary_key => descendants.map(&:id)).pluck(self.class.primary_key)
          descendants.select { |descendant| descendant_ids.include?(descendant.id) }
        else
          descendants
        end
      else
        super
      end
    end

    # Indirects with eager loading support
    def indirects(depth_options = {})
      if instance_variable_defined?(:@_eager_loaded_indirects)
        indirects = instance_variable_get(:@_eager_loaded_indirects)
        
        if depth_options.present?
          # Filter by depth if required
          indirect_depth = depth
          scope = self.class.ancestry_base_class.scope_depth(depth_options, indirect_depth)
          indirect_ids = scope.where(self.class.primary_key => indirects.map(&:id)).pluck(self.class.primary_key)
          indirects.select { |indirect| indirect_ids.include?(indirect.id) }
        else
          indirects
        end
      else
        super
      end
    end

    # Subtree with eager loading support
    def subtree(depth_options = {})
      if instance_variable_defined?(:@_eager_loaded_children)
        # Subtree is self + descendants
        subtree = [self] + collect_descendants
        
        if depth_options.present?
          # Filter by depth if required
          subtree_depth = depth
          scope = self.class.ancestry_base_class.scope_depth(depth_options, subtree_depth)
          subtree_ids = scope.where(self.class.primary_key => subtree.map(&:id)).pluck(self.class.primary_key)
          subtree.select { |node| subtree_ids.include?(node.id) }
        else
          subtree
        end
      else
        super
      end
    end
    
    # Path with eager loading support
    def path(depth_options = {})
      if instance_variable_defined?(:@_eager_loaded_ancestors) || instance_variable_defined?(:@_eager_loaded_parent)
        # Calculate the full path
        full_path = if instance_variable_defined?(:@_eager_loaded_ancestors) && instance_variable_get(:@_eager_loaded_ancestors)
          # If we have ancestors cached, use them directly
          instance_variable_get(:@_eager_loaded_ancestors) + [self]
        elsif instance_variable_defined?(:@_eager_loaded_parent) && instance_variable_get(:@_eager_loaded_parent)
          # If we have a parent cached, use it to build the path
          parent = instance_variable_get(:@_eager_loaded_parent)
          parent_path = parent.path(depth_options)
          parent_path + [self]
        else
          super(depth_options)
        end
        
        # Apply depth constraints if present
        if depth_options.present?
          node_depth = depth
          scope = self.class.ancestry_base_class.scope_depth(depth_options, node_depth)
          path_ids = scope.where(self.class.primary_key => full_path.map(&:id)).pluck(self.class.primary_key)
          full_path.select { |node| path_ids.include?(node.id) }
        else
          full_path
        end
      else
        super(depth_options)
      end
    end

    # Optional method to explicitly load all associations for a node
    def eager_load_ancestry(options = {})
      with_associations = options[:associations] || [:ancestors, :children, :descendants]
      
      with_associations.each do |association|
        case association
        when :ancestors
          self.class.ancestry_base_class.ancestors_of(self).to_a
          self.instance_variable_set(:@_eager_loaded_ancestors, ancestors)
        when :children
          self.class.ancestry_base_class.children_of(self).to_a
          self.instance_variable_set(:@_eager_loaded_children, children)
        when :descendants
          loaded_descendants = self.class.ancestry_base_class.descendants_of(self).to_a
          self.instance_variable_set(:@_eager_loaded_children, loaded_descendants.select { |d| d.parent_id == id })
        when :parent
          loaded_parent = parent
          self.instance_variable_set(:@_eager_loaded_parent, loaded_parent) if loaded_parent
        when :siblings
          loaded_siblings = self.class.ancestry_base_class.siblings_of(self).where.not(self.class.primary_key => id).to_a
          self.instance_variable_set(:@_eager_loaded_siblings, loaded_siblings)
        end
      end
      
      self
    end

    private

    # Helper method to recursively collect descendants
    def collect_descendants(nodes = [])
      children = instance_variable_get(:@_eager_loaded_children) || []
      
      children.each do |child|
        nodes << child
        if child.instance_variable_defined?(:@_eager_loaded_children)
          child.send(:collect_descendants, nodes)
        end
      end
      
      nodes
    end
  end
end
