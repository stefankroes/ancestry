module Ancestry
  module ClassMethods
    # Fetch tree node if necessary
    def to_node object
      if object.is_a?(self.base_class) then object else find(object) end
    end 
    
    # Scope on relative depth options
    def scope_depth depth_options, depth
      depth_options.inject(self.base_class) do |scope, option|
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
        raise Ancestry::AncestryException.new("Invalid orphan strategy, valid ones are :rootify, :restrict and :destroy.")
      end
    end
    
    # Arrangement
    def arrange options = {}
      scope =
        if options[:order].nil?
          self.base_class.ordered_by_ancestry
        else
          self.base_class.ordered_by_ancestry_and options.delete(:order)
        end
      # Get all nodes ordered by ancestry and start sorting them into an empty hash
      arrange_nodes scope.all(options)
    end
    
    # Arrange array of nodes into a nested hash of the form 
    # {node => children}, where children = {} if the node has no children
    def arrange_nodes(nodes)
      # Get all nodes ordered by ancestry and start sorting them into an empty hash
      nodes.inject(ActiveSupport::OrderedHash.new) do |arranged_nodes, node|
        # Find the insertion point for that node by going through its ancestors
        node.ancestor_ids.inject(arranged_nodes) do |insertion_point, ancestor_id|
          insertion_point.each do |parent, children|
            # Change the insertion point to children if node is a descendant of this parent
            insertion_point = children if ancestor_id == parent.id
          end
          insertion_point
        end[node] = ActiveSupport::OrderedHash.new
        arranged_nodes
      end
    end
    
    # Pseudo-preordered array of nodes.  Children will always follow parents, 
    # but the ordering of nodes within a rank depends on their order in the 
    # array that gets passed in
    def sort_by_ancestry(nodes)
      arranged = nodes.is_a?(Hash) ? nodes : arrange_nodes(nodes.sort_by{|n| n.ancestry || '0'})
      arranged.inject([]) do |sorted_nodes, pair|
        node, children = pair
        sorted_nodes << node
        sorted_nodes += sort_by_ancestry(children) unless children.blank?
        sorted_nodes
      end
    end

    # Integrity checking
    def check_ancestry_integrity! options = {}
      parents = {}
      exceptions = [] if options[:report] == :list
      # For each node ...
      self.base_class.find_each do |node|
        begin
          # ... check validity of ancestry column
          if !node.valid? and !node.errors[node.class.ancestry_column].blank?
            raise Ancestry::AncestryIntegrityException.new("Invalid format for ancestry column of node #{node.id}: #{node.read_attribute node.ancestry_column}.")
          end
          # ... check that all ancestors exist
          node.ancestor_ids.each do |ancestor_id|
            unless exists? ancestor_id
              raise Ancestry::AncestryIntegrityException.new("Reference to non-existent node in node #{node.id}: #{ancestor_id}.")
            end
          end
          # ... check that all node parents are consistent with values observed earlier
          node.path_ids.zip([nil] + node.path_ids).each do |node_id, parent_id|
            parents[node_id] = parent_id unless parents.has_key? node_id
            unless parents[node_id] == parent_id
              raise Ancestry::AncestryIntegrityException.new("Conflicting parent id found in node #{node.id}: #{parent_id || 'nil'} for node #{node_id} while expecting #{parents[node_id] || 'nil'}")
            end
          end
        rescue Ancestry::AncestryIntegrityException => integrity_exception
          case options[:report]
            when :list then exceptions << integrity_exception
            when :echo then puts integrity_exception
            else raise integrity_exception
          end
        end
      end
      exceptions if options[:report] == :list
    end

    # Integrity restoration
    def restore_ancestry_integrity!
      parents = {}
      # Wrap the whole thing in a transaction ...
      self.base_class.transaction do
        # For each node ...
        self.base_class.find_each do |node|
          # ... set its ancestry to nil if invalid
          if !node.valid? and !node.errors[node.class.ancestry_column].blank?
            node.without_ancestry_callbacks do
              node.update_attribute node.ancestry_column, nil
            end
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
        self.base_class.find_each do |node|
          # ... rebuild ancestry from parents array
          ancestry, parent = nil, parents[node.id]
          until parent.nil?
            ancestry, parent = if ancestry.nil? then parent else "#{parent}/#{ancestry}" end, parents[parent]
          end
          node.without_ancestry_callbacks do
            node.update_attribute node.ancestry_column, ancestry
          end
        end
      end
    end
    
    # Build ancestry from parent id's for migration purposes
    def build_ancestry_from_parent_ids! parent_id = nil, ancestry = nil
      self.base_class.find_each(:conditions => {:parent_id => parent_id}) do |node|
        node.without_ancestry_callbacks do
          node.update_attribute ancestry_column, ancestry
        end
        build_ancestry_from_parent_ids! node.id, if ancestry.nil? then "#{node.id}" else "#{ancestry}/#{node.id}" end
      end
    end
    
    # Rebuild depth cache if it got corrupted or if depth caching was just turned on
    def rebuild_depth_cache!
      raise Ancestry::AncestryException.new("Cannot rebuild depth cache for model without depth caching.") unless respond_to? :depth_cache_column
      self.base_class.find_each do |node|
        node.update_attribute depth_cache_column, node.depth
      end
    end
  end
end
