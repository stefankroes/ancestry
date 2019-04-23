module Ancestry
  module ClassMethods
    # Fetch tree node if necessary
    def to_node object
      if object.is_a?(self.ancestry_base_class) then object else unscoped_where{|scope| scope.find object} end
    end

    # Scope on relative depth options
    def scope_depth depth_options, depth
      depth_options.inject(self.ancestry_base_class) do |scope, option|
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
      # Check value of orphan strategy, only rootify, adopt, restrict or destroy is allowed
      if [:rootify, :adopt, :restrict, :destroy].include? orphan_strategy
        class_variable_set :@@orphan_strategy, orphan_strategy
      else
        raise Ancestry::AncestryException.new("Invalid orphan strategy, valid ones are :rootify,:adopt, :restrict and :destroy.")
      end
    end

    # Get all nodes and sorting them into an empty hash
    def arrange options = {}
      if (order = options.delete(:order))
        arrange_nodes self.ancestry_base_class.order(order).where(options)
      else
        arrange_nodes self.ancestry_base_class.where(options)
      end
    end

    # Arrange array of nodes into a nested hash of the form
    # {node => children}, where children = {} if the node has no children
    # If a node's parent is not included, the node will be included as if it is a top level node
    def arrange_nodes(nodes)
      node_ids = Set.new(nodes.map(&:id))
      index = Hash.new { |h, k| h[k] = {} }

      nodes.each_with_object({}) do |node, arranged|
        children = index[node.id]
        index[node.parent_id][node] = children
        arranged[node] = children unless node_ids.include?(node.parent_id)
      end
    end

     # Arrangement to nested array
    def arrange_serializable options={}, nodes=nil, &block
      nodes = arrange(options) if nodes.nil?
      nodes.map do |parent, children|
        if block_given?
          yield parent, arrange_serializable(options, children, &block)
        else
          parent.serializable_hash.merge 'children' => arrange_serializable(options, children)
        end
      end
    end

    # Pseudo-preordered array of nodes.  Children will always follow parents,
    # for ordering nodes within a rank provide block, eg. Node.sort_by_ancestry(Node.all) {|a, b| a.rank <=> b.rank}.
    def sort_by_ancestry(nodes, &block)
      arranged = nodes if nodes.is_a?(Hash)

      unless arranged
        presorted_nodes = nodes.sort do |a, b|
          a_cestry, b_cestry = a.ancestry || '0', b.ancestry || '0'

          if block_given? && a_cestry == b_cestry
            yield a, b
          else
            a_cestry <=> b_cestry
          end
        end

        arranged = arrange_nodes(presorted_nodes)
      end

      arranged.inject([]) do |sorted_nodes, pair|
        node, children = pair
        sorted_nodes << node
        sorted_nodes += sort_by_ancestry(children, &block) unless children.blank?
        sorted_nodes
      end
    end

    # Integrity checking
    def check_ancestry_integrity! options = {}
      parents = {}
      exceptions = [] if options[:report] == :list

      unscoped_where do |scope|
        # For each node ...
        scope.find_each do |node|
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
      end
      exceptions if options[:report] == :list
    end

    # Integrity restoration
    def restore_ancestry_integrity!
      parents = {}
      # Wrap the whole thing in a transaction ...
      self.ancestry_base_class.transaction do
        unscoped_where do |scope|
          # For each node ...
          scope.find_each do |node|
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
          scope.find_each do |node|
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
    end

    # Build ancestry from parent id's for migration purposes
    def build_ancestry_from_parent_ids! parent_id = nil, ancestry = nil
      unscoped_where do |scope|
        scope.where(:parent_id => parent_id).find_each do |node|
          node.without_ancestry_callbacks do
            node.update_attribute ancestry_column, ancestry
          end
          build_ancestry_from_parent_ids! node.id, if ancestry.nil? then "#{node.id}" else "#{ancestry}/#{node.id}" end
        end
      end
    end

    # Rebuild depth cache if it got corrupted or if depth caching was just turned on
    def rebuild_depth_cache!
      raise Ancestry::AncestryException.new("Cannot rebuild depth cache for model without depth caching.") unless respond_to? :depth_cache_column

      self.ancestry_base_class.transaction do
        unscoped_where do |scope|
          scope.find_each do |node|
            node.update_attribute depth_cache_column, node.depth
          end
        end
      end
    end

    def unscoped_where
      if ActiveRecord::VERSION::MAJOR < 4
        self.ancestry_base_class.unscoped do
          yield self.ancestry_base_class
        end
      else
        yield self.ancestry_base_class.unscope(:where)
      end
    end

    ANCESTRY_UNCAST_TYPES = [:string, :uuid, :text].freeze
    if ActiveSupport::VERSION::STRING < "4.2"
      def primary_key_is_an_integer?
        if defined?(@primary_key_is_an_integer)
          @primary_key_is_an_integer
        else
          @primary_key_is_an_integer = !ANCESTRY_UNCAST_TYPES.include?(columns_hash[primary_key.to_s].type)
        end
      end
    else
      def primary_key_is_an_integer?
        if defined?(@primary_key_is_an_integer)
          @primary_key_is_an_integer
        else
          @primary_key_is_an_integer = !ANCESTRY_UNCAST_TYPES.include?(type_for_attribute(primary_key).type)
        end
      end
    end
  end
end
