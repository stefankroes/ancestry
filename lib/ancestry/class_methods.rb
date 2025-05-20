# frozen_string_literal: true

module Ancestry
  module ClassMethods
    # Fetch tree node if necessary
    # Supports single objects or arrays for batch loading
    def to_node(object)
      if object.is_a?(ancestry_base_class)
        object
      elsif object.is_a?(Array)
        # Batch load multiple nodes at once to avoid N+1 queries
        ids = object.map { |obj| obj.try(primary_key) || obj }
        nodes = unscoped_where { |scope| scope.where(primary_key => ids) }
        object.map { |obj| nodes.find { |n| n.id.to_s == (obj.try(primary_key) || obj).to_s } }
      else
        unscoped_where { |scope| scope.find(object.try(primary_key) || object) }
      end
    end

    # Scope on relative depth options
    def scope_depth(depth_options, depth)
      depth_options.inject(ancestry_base_class) do |scope, option|
        scope_name, relative_depth = option
        if [:before_depth, :to_depth, :at_depth, :from_depth, :after_depth].include? scope_name
          scope.send scope_name, depth + relative_depth
        else
          raise Ancestry::AncestryException, I18n.t("ancestry.unknown_depth_option", scope_name: scope_name)
        end
      end
    end

    # these methods arrange an entire subtree into nested hashes for easy navigation after database retrieval
    # the arrange method also works on a scoped class
    # the arrange method takes ActiveRecord find options
    # To order your hashes pass the order to the arrange method instead of to the scope

    # Get all nodes and sort them into an empty hash
    # Supports eager loading of associations
    def arrange(options = {})
      scope = ancestry_base_class
      
      if (includes_param = options.delete(:includes))
        scope = scope.includes(includes_param)
      end
      
      if (preload_param = options.delete(:preload))
        scope = scope.preload(preload_param)
      end
      
      if (eager_load_param = options.delete(:eager_load))
        scope = scope.eager_load(eager_load_param)
      end
      
      if (order = options.delete(:order))
        arrange_nodes(scope.order(order).where(options))
      else
        arrange_nodes(scope.where(options))
      end
    end

    # arranges array of nodes to a hierarchical hash
    #
    # @param nodes [Array[Node]] nodes to be arranged
    # @returns Hash{Node => {Node => {}, Node => {}}}
    # If a node's parent is not included, the node will be included as if it is a top level node
    def arrange_nodes(nodes)
      return {} if nodes.blank?
      
      # Check if nodes are eager loaded
      if nodes.first.instance_variable_defined?(:@_eager_loaded_children) && 
         nodes.first.instance_variable_defined?(:@_eager_loaded_parent)
        # Use eager loaded data for faster arrangement
        return arrange_eager_loaded_nodes(nodes)
      end
      
      # Optimize by only creating the Set once and using a more efficient hash initialization
      node_ids = Set.new(nodes.map(&:id))
      index = {}
      
      # First pass: initialize all entries in the index
      nodes.each do |node|
        index[node.id] ||= {}
      end
      
      # Second pass: build parent-child relationships
      arranged = {}
      nodes.each do |node|
        # Get or initialize the children hash
        children = index[node.id]
        parent_id = node.parent_id
        
        # Add this node as a child to its parent in our index
        parent_children = (index[parent_id] ||= {})
        parent_children[node] = children
        
        # If this node's parent is not in our nodes collection, 
        # add the node directly to the arranged hash
        arranged[node] = children unless node_ids.include?(parent_id)
      end
      
      arranged
    end
    
    # Arranges nodes that have been eager loaded
    # This is much faster as parent-child relationships are already in memory
    def arrange_eager_loaded_nodes(nodes)
      arranged = {}
      nodes_by_id = {}
      
      # Index nodes by id for quick lookup
      nodes.each do |node|
        nodes_by_id[node.id] = node
      end
      
      # Build the arranged hash
      nodes.each do |node|
        # Skip if this node is already processed as a child
        next if node.instance_variable_defined?(:@_in_arranged_hash) && 
                node.instance_variable_get(:@_in_arranged_hash)
        
        children = node.instance_variable_get(:@_eager_loaded_children) || []
        parent = node.instance_variable_get(:@_eager_loaded_parent)
        
        if parent.nil? || !nodes_by_id.key?(parent.id)
          # This is a root node in our collection
          arranged[node] = arrange_eager_loaded_children(node, children)
        end
      end
      
      arranged
    end
    
    # Helper method to recursively arrange eager loaded children
    def arrange_eager_loaded_children(node, children)
      result = {}
      
      children.each do |child|
        child.instance_variable_set(:@_in_arranged_hash, true)
        grand_children = child.instance_variable_get(:@_eager_loaded_children) || []
        result[child] = arrange_eager_loaded_children(child, grand_children)
      end
      
      result
    end

    # convert a hash of the form {node => children} to an array of nodes, child first
    #
    # @param arranged [Hash{Node => {Node => {}, Node => {}}}] arranged nodes
    # @returns [Array[Node]] array of nodes with the parent before the children
    def flatten_arranged_nodes(arranged, nodes = [])
      arranged.each do |node, children|
        nodes << node
        flatten_arranged_nodes(children, nodes) unless children.empty?
      end
      nodes
    end

    # Arrangement to nested array for serialization
    # You can also supply your own serialization logic using blocks
    # also allows you to pass the order just as you can pass it to the arrange method
    # Supports eager loading of associations
    def arrange_serializable(options = {}, nodes = nil, &block)
      nodes = arrange(options) if nodes.nil?
      nodes.map do |parent, children|
        if block_given?
          yield parent, arrange_serializable(options, children, &block)
        else
          parent.serializable_hash.merge 'children' => arrange_serializable(options, children)
        end
      end
    end
    
    # Efficiently load a tree structure with all descendants preloaded
    # This helps avoid N+1 queries when working with tree structures
    # @param root_nodes [Array] Array of root nodes
    # @param options [Hash] Options to customize loading behavior
    # @option options [Symbol,Array] :includes Associations to include
    # @option options [Integer] :depth_limit Limit how deep to load the tree
    # @return [Array] Root nodes with descendants preloaded
    def preload_tree(root_nodes, options = {})
      depth_limit = options[:depth_limit]
      includes_param = options[:includes]
      
      # Early return if no root nodes or depth limit is 0
      return root_nodes if root_nodes.empty? || depth_limit == 0
      
      # Get all descendants in a single query
      descendant_conditions = root_nodes.map { |node| descendant_conditions(node) }
                                       .reduce { |a, b| a.or(b) }
      descendants_scope = ancestry_base_class.where(descendant_conditions)
      
      # Apply depth limit if specified
      if depth_limit && respond_to?(:depth_cache_column)
        max_depth = root_nodes.map(&:depth).max + depth_limit
        descendants_scope = descendants_scope.where("#{depth_cache_column} <= ?", max_depth)
      end
      
      # Apply includes if specified
      descendants_scope = descendants_scope.includes(includes_param) if includes_param
      
      # Load all descendants in a single query
      descendants = descendants_scope.to_a
      
      # Arrange the descendants into a hash for quick lookup
      nodes_by_ancestry = {}
      descendants.each do |node|
        ancestry_key = node.read_attribute(ancestry_column)
        nodes_by_ancestry[ancestry_key] ||= []
        nodes_by_ancestry[ancestry_key] << node
      end
      
      # Function to recursively preload children
      preload_children = lambda do |nodes|
        nodes.each do |node|
          ancestry_value = node.child_ancestry
          if children = nodes_by_ancestry[ancestry_value]
            association = node.association(:children)
            association.target = children
            association.loaded!
            preload_children.call(children) # Recursively preload deeper children
          else
            # Ensure the children association is marked as loaded even when empty
            association = node.association(:children)
            association.target = []
            association.loaded!
          end
        end
      end
      
      # Preload children for root nodes
      preload_children.call(root_nodes)
      
      root_nodes
    end

    def tree_view(column, data = nil)
      data ||= arrange
      data.each do |parent, children|
        if parent.depth == 0
          puts parent[column]
        else
          num = parent.depth - 1
          indent = "   " * num
          puts " #{"|" if parent.depth > 1}#{indent}|_ #{parent[column]}"
        end
        tree_view(column, children) if children
      end
    end

    # Pseudo-preordered array of nodes.  Children will always follow parents,
    # This is deterministic unless the parents are missing *and* a sort block is specified
    def sort_by_ancestry(nodes)
      arranged = nodes if nodes.is_a?(Hash)

      unless arranged
        presorted_nodes = nodes.sort do |a, b|
          rank = (a.public_send(ancestry_column) || ' ') <=> (b.public_send(ancestry_column) || ' ')
          rank = yield(a, b) if rank == 0 && block_given?
          rank
        end

        arranged = arrange_nodes(presorted_nodes)
      end

      flatten_arranged_nodes(arranged)
    end

    # Integrity checking
    # compromised tree integrity is unlikely without explicitly setting cyclic parents or invalid ancestry and circumventing validation
    # just in case, raise an AncestryIntegrityException if issues are detected
    # specify :report => :list to return an array of exceptions or :report => :echo to echo any error messages
    def check_ancestry_integrity!(options = {})
      parents = {}
      exceptions = [] if options[:report] == :list

      unscoped_where do |scope|
        # For each node ...
        scope.find_each do |node|
          # ... check validity of ancestry column
          if !node.sane_ancestor_ids?
            raise Ancestry::AncestryIntegrityException, I18n.t("ancestry.invalid_ancestry_column",
                                                               :node_id => node.id,
                                                               :ancestry_column => node.read_attribute(node.class.ancestry_column))
          end
          # ... check that all ancestors exist
          node.ancestor_ids.each do |ancestor_id|
            unless exists?(ancestor_id)
              raise Ancestry::AncestryIntegrityException, I18n.t("ancestry.reference_nonexistent_node",
                                                                 :node_id => node.id,
                                                                 :ancestor_id => ancestor_id)
            end
          end
          # ... check that all node parents are consistent with values observed earlier
          node.path_ids.zip([nil] + node.path_ids).each do |node_id, parent_id|
            parents[node_id] = parent_id unless parents.key?(node_id)
            unless parents[node_id] == parent_id
              raise Ancestry::AncestryIntegrityException, I18n.t("ancestry.conflicting_parent_id",
                                                                 :node_id => node_id,
                                                                 :parent_id => parent_id || 'nil',
                                                                 :expected => parents[node_id] || 'nil')
            end
          end
        rescue Ancestry::AncestryIntegrityException => e
          case options[:report]
          when :list then exceptions << e
          when :echo then puts e
          else raise e
          end
        end
      end
      exceptions if options[:report] == :list
    end

    # Integrity restoration
    def restore_ancestry_integrity!
      parent_ids = {}
      # Wrap the whole thing in a transaction ...
      ancestry_base_class.transaction do
        unscoped_where do |scope|
          # For each node ...
          scope.find_each do |node|
            # ... set its ancestry to nil if invalid
            if !node.sane_ancestor_ids?
              node.without_ancestry_callbacks do
                node.update_attribute :ancestor_ids, []
              end
            end
            # ... save parent id of this node in parent_ids array if it exists
            parent_ids[node.id] = node.parent_id if exists? node.parent_id

            # Reset parent id in array to nil if it introduces a cycle
            parent_id = parent_ids[node.id]
            until parent_id.nil? || parent_id == node.id
              parent_id = parent_ids[parent_id]
            end
            parent_ids[node.id] = nil if parent_id == node.id
          end

          # For each node ...
          scope.find_each do |node|
            # ... rebuild ancestry from parent_ids array
            ancestor_ids, parent_id = [], parent_ids[node.id]
            until parent_id.nil?
              ancestor_ids, parent_id = [parent_id] + ancestor_ids, parent_ids[parent_id]
            end
            node.without_ancestry_callbacks do
              node.update_attribute :ancestor_ids, ancestor_ids
            end
          end
        end
      end
    end

    # Build ancestry from parent ids for migration purposes
    def build_ancestry_from_parent_ids!(column = :parent_id, parent_id = nil, ancestor_ids = [])
      unscoped_where do |scope|
        scope.where(column => parent_id).find_each do |node|
          node.without_ancestry_callbacks do
            node.update_attribute :ancestor_ids, ancestor_ids
          end
          build_ancestry_from_parent_ids! column, node.id, ancestor_ids + [node.id]
        end
      end
    end

    # Rebuild depth cache if it got corrupted or if depth caching was just turned on
    def rebuild_depth_cache!
      raise(Ancestry::AncestryException, I18n.t("ancestry.cannot_rebuild_depth_cache")) unless respond_to?(:depth_cache_column)

      ancestry_base_class.transaction do
        unscoped_where do |scope|
          scope.find_each do |node|
            node.update_attribute depth_cache_column, node.depth
          end
        end
      end
    end

    # NOTE: this is temporarily kept separate from rebuild_depth_cache!
    # this will become the implementation of rebuild_depth_cache!
    def rebuild_depth_cache_sql!
      update_all("#{depth_cache_column} = #{ancestry_depth_sql}")
    end

    def rebuild_counter_cache!
      if %w(mysql mysql2).include?(connection.adapter_name.downcase)
        connection.execute %{
          UPDATE #{table_name} AS dest
          LEFT JOIN (
            SELECT #{table_name}.#{primary_key}, COUNT(*) AS child_count
            FROM #{table_name}
            JOIN #{table_name} children ON children.#{ancestry_column} = (#{child_ancestry_sql})
            GROUP BY #{table_name}.#{primary_key}
          ) src USING(#{primary_key})
          SET dest.#{counter_cache_column} = COALESCE(src.child_count, 0)
        }
      else
        update_all %{
          #{counter_cache_column} = (
            SELECT COUNT(*)
            FROM #{table_name} children
            WHERE children.#{ancestry_column} = (#{child_ancestry_sql})
          )
        }
      end
    end

    def unscoped_where
      yield ancestry_base_class.default_scoped.unscope(:where)
    end

    ANCESTRY_UNCAST_TYPES = [:string, :uuid, :text].freeze
    def primary_key_is_an_integer?
      if defined?(@primary_key_is_an_integer)
        @primary_key_is_an_integer
      else
        @primary_key_is_an_integer = !ANCESTRY_UNCAST_TYPES.include?(type_for_attribute(primary_key).type)
      end
    end
  end
end
