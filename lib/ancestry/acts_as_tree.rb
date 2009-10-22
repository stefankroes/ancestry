module Ancestry
  class AncestryException < RuntimeError
  end

  class AncestryIntegrityException < AncestryException
  end
  
  def self.included base
    base.send :extend, ClassMethods
  end
  
  module ClassMethods
    def acts_as_tree options = {}
      # Check options
      raise AncestryException.new("Options for acts_as_tree must be in a hash.") unless options.is_a? Hash
      options.each do |key, value|
        unless [:ancestry_column, :orphan_strategy, :cache_depth, :depth_cache_column].include? key
          raise AncestryException.new("Unknown options for acts_as_tree: #{key.inspect} => #{value.inspect}.")
        end
      end
      
      # Include instance methods
      send :include, InstanceMethods

      # Include dynamic class methods
      send :extend, DynamicClassMethods

      # Create ancestry column accessor and set to option or default
      self.cattr_accessor :ancestry_column
      self.ancestry_column = options[:ancestry_column] || :ancestry

      # Create orphan strategy accessor and set to option or default (writer comes from DynamicClassMethods)
      self.cattr_reader :orphan_strategy
      self.orphan_strategy = options[:orphan_strategy] || :destroy

      # Validate format of ancestry column value
      validates_format_of ancestry_column, :with => /^[0-9]+(\/[0-9]+)*$/, :allow_nil => true
      
      # Create ancestry column accessor and set to option or default
      if options[:cache_depth]
        self.cattr_accessor :depth_cache_column
        self.depth_cache_column = options[:depth_cache_column] || :ancestry_depth
        # Cache depth in depth cache column before save
        before_save :cache_depth
        # Named scopes for depth
      end
      
      # Create named scopes for depth
      named_scope :before_depth, lambda { |depth|
        raise AncestryException.new("Named scope 'before_depth' is only available when depth caching is enabled.") unless options[:cache_depth]
        {:conditions => ["#{depth_cache_column} < ?", depth]}
      }
      named_scope :to_depth, lambda { |depth|
        raise AncestryException.new("Named scope 'to_depth' is only available when depth caching is enabled.") unless options[:cache_depth]
        {:conditions => ["#{depth_cache_column} <= ?", depth]}
      }
      named_scope :at_depth, lambda { |depth|
        raise AncestryException.new("Named scope 'at_depth' is only available when depth caching is enabled.") unless options[:cache_depth]
        {:conditions => ["#{depth_cache_column} = ?",  depth]}
      }
      named_scope :from_depth, lambda { |depth|
        raise AncestryException.new("Named scope 'from_depth' is only available when depth caching is enabled.") unless options[:cache_depth]
        {:conditions => ["#{depth_cache_column} >= ?", depth]}
      }
      named_scope :after_depth, lambda { |depth|
        raise AncestryException.new("Named scope 'after_depth' is only available when depth caching is enabled.") unless options[:cache_depth]
        {:conditions => ["#{depth_cache_column} > ?", depth]}
      }

      # Validate that the ancestor ids don't include own id
      validate :ancestry_exclude_self
      
      # Named scopes
      named_scope :roots, :conditions => {ancestry_column => nil}
      named_scope :ancestors_of, lambda { |object| {:conditions => to_node(object).ancestor_conditions} }
      named_scope :children_of, lambda { |object| {:conditions => to_node(object).child_conditions} }
      named_scope :descendants_of, lambda { |object| {:conditions => to_node(object).descendant_conditions} }
      named_scope :siblings_of, lambda { |object| {:conditions => to_node(object).sibling_conditions} }
      
      # Update descendants with new ancestry before save
      before_save :update_descendants_with_new_ancestry

      # Apply orphan strategy before destroy
      before_destroy :apply_orphan_strategy
    end
  end
  
  module DynamicClassMethods
    # Fetch tree node if necessary
    def to_node object
      if object.is_a?(self) then object else find(object) end
    end 
    
    # Scope on relative depth options
    def scope_depth depth_options, depth
      depth_options.inject(self) do |scope, option|
        scope_name, relative_depth = option
        if [:before_depth, :to_depth, :at_depth, :from_depth, :after_depth].include? scope_name
          scope.send scope_name, depth + relative_depth
        else
          raise Ancestry::AncestryException.new("Unknown depth option: #{scope_name}.")
        end
      end
    end

    # Orphan strategy writer
    def orphan_strategy= orphan_strategy
      # Check value of orphan strategy, only rootify, restrict or destroy is allowed
      if [:rootify, :restrict, :destroy].include? orphan_strategy
        class_variable_set :@@orphan_strategy, orphan_strategy
      else
        raise AncestryException.new("Invalid orphan strategy, valid ones are :rootify, :restrict and :destroy.")
      end
    end
    
    # Arrangement
    def arrange
      # Get all nodes ordered by ancestry and start sorting them into an empty hash
      all(:order => ancestry_column).inject({}) do |arranged_nodes, node|
        # Find the insertion point for that node by going through its ancestors
        node.ancestor_ids.inject(arranged_nodes) do |insertion_point, ancestor_id|
          insertion_point.each do |parent, children|
            # Change the insertion point to children if node is a descendant of this parent
            insertion_point = children if ancestor_id == parent.id
          end; insertion_point
        end[node] = {}; arranged_nodes
      end
    end

    # Integrity checking
    def check_ancestry_integrity!
      parents = {}
      # For each node ...
      all.each do |node|
        # ... check validity of ancestry column
        if node.errors.invalid? node.class.ancestry_column
          raise AncestryIntegrityException.new "Invalid format for ancestry column of node #{node.id}: #{node.read_attribute node.ancestry_column}."
        end
        # ... check that all ancestors exist
        node.ancestor_ids.each do |node_id|
          unless exists? node_id
            raise AncestryIntegrityException.new "Reference to non-existent node in node #{node.id}: #{node_id}."
          end
        end
        # ... check that all node parents are consistent with values observed earlier
        node.path_ids.zip([nil] + node.path_ids).each do |node_id, parent_id|
          parents[node_id] = parent_id unless parents.has_key? node_id
          unless parents[node_id] == parent_id
            raise AncestryIntegrityException.new "Conflicting parent id in node #{node.id}: #{parent_id || 'nil'} for node #{node_id}, expecting #{parents[node_id] || 'nil'}"
          end
        end
      end
    end

    # Integrity restoration
    def restore_ancestry_integrity!
      parents = {}
      # For each node ...
      all.each do |node|
        # ... set its ancestry to nil if invalid
        if node.errors.invalid? node.class.ancestry_column
          node.update_attributes :ancestry => nil
        end
        # ... save parent of this node in parents array if it exists
        parents[node.id] = node.parent_id if exists? node.parent_id

        # Reset parent id in array to nil if it introduces a cycle
        parent = parents[node.id]
        until parent.nil? || parent == node.id
          parent = parents[parent]
        end
        parents[node.id] = nil if parent == node.id 
      end
      # For each node ...
      all.each do |node|
        # ... rebuild ancestry from parents array
        ancestry, parent = nil, parents[node.id]
        until parent.nil?
          ancestry, parent = if ancestry.nil? then parent else "#{parent}/#{ancestry}" end, parents[parent]
        end
        node.update_attributes node.ancestry_column => ancestry
      end
    end
    
    # Build ancestry from parent id's for migration purposes
    def build_ancestry_from_parent_ids! parent_id = nil, ancestry = nil
      all(:conditions => {:parent_id => parent_id}).each do |node|
        node.update_attribute ancestry_column, ancestry
        build_ancestry_from_parent_ids! node.id, if ancestry.nil? then "#{node.id}" else "#{ancestry}/#{node.id}" end
      end
    end
    
    # Build ancestry from parent id's for migration purposes
    def rebuild_depth_cache!
      raise Ancestry::AncestryException.new("Cannot rebuild depth cache for model without depth caching.") unless respond_to? :depth_cache_column
      all.each do |node|
        node.update_attribute depth_cache_column, node.depth
      end
    end
  end

  module InstanceMethods 
    # Validate that the ancestors don't include itself
    def ancestry_exclude_self
      errors.add_to_base "#{self.class.name.humanize} cannot be a descendant of itself." if ancestor_ids.include? self.id
    end

    # Update descendants with new ancestry
    def update_descendants_with_new_ancestry
      # If node is valid, not a new record and ancestry was updated ...
      if changed.include?(self.class.ancestry_column.to_s) && !new_record? && valid?
        # ... for each descendant ...
        descendants.each do |descendant|
          # ... replace old ancestry with new ancestry
          descendant.update_attributes(
            self.class.ancestry_column =>
            descendant.read_attribute(descendant.class.ancestry_column).gsub(
              /^#{self.child_ancestry}/, 
              if read_attribute(self.class.ancestry_column).blank? then id.to_s else "#{read_attribute self.class.ancestry_column }/#{id}" end
            )
          )
        end
      end
    end

    # Apply orphan strategy
    def apply_orphan_strategy
      # If this isn't a new record ...
      unless new_record?
        # ... make al children root if orphan strategy is rootify
        if self.class.orphan_strategy == :rootify
          descendants.each do |descendant|
            descendant.update_attributes descendant.class.ancestry_column => (if descendant.ancestry == child_ancestry then nil else descendant.ancestry.gsub(/^#{child_ancestry}\//, '') end)
          end
        # ... destroy all descendants if orphan strategy is destroy
        elsif self.class.orphan_strategy == :destroy
          self.class.destroy_all descendant_conditions
        # ... throw an exception if it has children and orphan strategy is restrict
        elsif self.class.orphan_strategy == :restrict
          raise Ancestry::AncestryException.new('Cannot delete record because it has descendants.') unless is_childless?
        end
      end
    end
    
    # The ancestry value for this record's children
    def child_ancestry
      # New records cannot have children
      raise Ancestry::AncestryException.new('No child ancestry for new record. Save record before performing tree operations.') if new_record?

      if self.send("#{self.class.ancestry_column}_was").blank? then id.to_s else "#{self.send "#{self.class.ancestry_column}_was"}/#{id}" end
    end

    # Ancestors
    def ancestor_ids
      read_attribute(self.class.ancestry_column).to_s.split('/').map(&:to_i)
    end

    def ancestor_conditions
      {:id => ancestor_ids}
    end

    def ancestors depth_options = {}
      self.class.scope_depth(depth_options, depth).scoped :conditions => ancestor_conditions, :order => self.class.ancestry_column
    end
    
    def path_ids
      ancestor_ids + [id]
    end

    def path_conditions
      {:id => path_ids}
    end

    def path depth_options = {}
      self.class.scope_depth(depth_options, depth).scoped :conditions => path_conditions, :order => self.class.ancestry_column
    end
    
    def depth
      ancestor_ids.size
    end
    
    def cache_depth
      write_attribute self.class.depth_cache_column, depth
    end

    # Parent
    def parent= parent
      write_attribute(self.class.ancestry_column, if parent.blank? then nil else parent.child_ancestry end)
    end

    def parent_id= parent_id
      self.parent = if parent_id.blank? then nil else self.class.find(parent_id) end
    end

    def parent_id
      if ancestor_ids.empty? then nil else ancestor_ids.last end
    end

    def parent
      if parent_id.blank? then nil else self.class.find(parent_id) end
    end

    # Root
    def root_id
      if ancestor_ids.empty? then id else ancestor_ids.first end
    end

    def root
      if root_id == id then self else self.class.find(root_id) end
    end

    def is_root?
      read_attribute(self.class.ancestry_column).blank?
    end

    # Children
    def child_conditions
      {self.class.ancestry_column => child_ancestry}
    end

    def children
      self.class.scoped :conditions => child_conditions
    end

    def child_ids
      children.all(:select => :id).map(&:id)
    end

    def has_children?
      self.children.exists?
    end

    def is_childless?
      !has_children?
    end

    # Siblings
    def sibling_conditions
      {self.class.ancestry_column => read_attribute(self.class.ancestry_column)}
    end

    def siblings
      self.class.scoped :conditions => sibling_conditions
    end

    def sibling_ids
       siblings.all(:select => :id).collect(&:id)
    end

    def has_siblings?
      self.siblings.count > 1
    end

    def is_only_child?
      !has_siblings?
    end

    # Descendants
    def descendant_conditions
      ["#{self.class.ancestry_column} like ? or #{self.class.ancestry_column} = ?", "#{child_ancestry}/%", child_ancestry]
    end

    def descendants depth_options = {}
      self.class.scope_depth(depth_options, depth).scoped :conditions => descendant_conditions
    end

    def descendant_ids depth_options = {}
      descendants(depth_options).all(:select => :id).collect(&:id)
    end
    
    # Subtree
    def subtree_conditions
      ["id = ? or #{self.class.ancestry_column} like ? or #{self.class.ancestry_column} = ?", self.id, "#{child_ancestry}/%", child_ancestry]
    end

    def subtree depth_options = {}
      self.class.scope_depth(depth_options, depth).scoped :conditions => subtree_conditions
    end

    def subtree_ids depth_options = {}
      subtree(depth_options).all(:select => :id).collect(&:id)
    end
  end
end

ActiveRecord::Base.send :include, Ancestry