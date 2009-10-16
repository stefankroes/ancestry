class Hash
  def ppp indent = 0
    each do |k,v|
      puts "#{' ' * indent}#{k.inspect}:"
      if v.is_a? Hash
        v.ppp indent + 2
      else
        puts "#{' ' * indent}  #{v.inspect}"
      end
    end
  end
end

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
      
      # Named scopes
      named_scope :root, :conditions => {ancestry_column => nil}
      named_scope :ancestor_of, lambda{ |object| {:conditions => to_node(object).ancestor_conditions} }
      named_scope :child_of, lambda{ |object| {:conditions => to_node(object).child_conditions} }
      named_scope :descendant_of, lambda{ |object| {:conditions => to_node(object).descendant_conditions} }
      named_scope :sibling_of, lambda{ |object| {:conditions => to_node(object).sibling_conditions} }
      
      # Update descendants with new ancestry before save
      before_save :update_descendants_with_new_ancestry

      # Apply orphan strategy before destroy
      before_destroy :apply_orphan_strategy
    end
  end
  
  module DynamicClassMethods
    # Fetch tree node if necessary
    def to_node object
      object.is_a?(self) ? object : find(object)
    end 
    
    # Orhpan strategy writer
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
    def check_ancestry_integrity
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
    def restore_ancestry_integrity
      parents = {}
      # For each node ...
      all.each do |node|
        # ... set its ancestry to nil if invalid
        if node.errors.invalid? node.class.ancestry_column
          node.update_attribute :ancestry, nil
        end
        # ... save parent of this node in parents array if it actually exists
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
          ancestry, parent = ancestry.nil? ? parent : "#{parent}/#{ancestry}", parents[parent]
        end
        node.update_attribute node.ancestry_column, ancestry
      end
    end
  end

  module InstanceMethods 
    # Fetch tree node if necessary
    def self.to_node object
      object.is_a?(self) ? object : find(object)
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
              (read_attribute(self.class.ancestry_column).blank? ? id.to_s : "#{read_attribute self.class.ancestry_column }/#{id}")
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
            descendant.update_attributes descendant.class.ancestry_column => descendant.ancestry == child_ancestry ? nil : descendant.ancestry.gsub(/^#{child_ancestry}\//, '')
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

      self.send("#{self.class.ancestry_column}_was").blank? ? id.to_s : "#{self.send "#{self.class.ancestry_column}_was"}/#{id}"
    end

    # Ancestors
    def ancestor_ids
      read_attribute(self.class.ancestry_column).to_s.split('/').map(&:to_i)
    end

    def ancestor_conditions
      {:id => ancestor_ids}
    end

    def ancestors
      self.class.scoped :conditions => ancestor_conditions
    end
    
    def path_ids
      ancestor_ids + [id]
    end

    def path
      ancestors + [self]
    end

    # Parent
    def parent= parent
      write_attribute(self.class.ancestry_column, parent.blank? ? nil : parent.child_ancestry)
    end

    def parent_id= parent_id
      self.parent = parent_id.blank? ? nil : self.class.find(parent_id)
    end

    def parent_id
      ancestor_ids.empty? ? nil : ancestor_ids.last
    end

    def parent
      parent_id.blank? ? nil : self.class.find(parent_id)
    end

    # Root
    def root_id
      ancestor_ids.empty? ? id : ancestor_ids.first
    end

    def root
      root_id == id ? self : self.class.find(root_id)
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

    def descendants
      self.class.scoped :conditions => descendant_conditions
    end

    def descendant_ids
      descendants.all(:select => :id).collect(&:id)
    end
    
    def subtree
      [self] + descendants
    end

    def subtree_ids
      [self.id] + descendant_ids
    end
  end
end

ActiveRecord::Base.send :include, Ancestry