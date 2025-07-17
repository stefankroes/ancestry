# frozen_string_literal: true

module Ancestry
  module ClassMethods
    # Fetch tree node if necessary
    def to_node(object)
      if object.is_a?(ancestry_base_class)
        object
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
    def arrange(options = {})
      if (order = options.delete(:order))
        arrange_nodes(ancestry_base_class.order(order).where(options))
      else
        arrange_nodes(ancestry_base_class.where(options))
      end
    end

    # arranges array of nodes to a hierarchical hash
    #
    # @param nodes [Array[Node]] nodes to be arranged
    # @param orphan_strategy [Symbol]  :rootify or :destroy (default: :rootify)
    # @returns Hash{Node => {Node => {}, Node => {}}}
    # If a node's parent is not included, the node will be included as if it is a top level node
    def arrange_nodes(nodes, orphan_strategy: :rootify)
      node_ids = Set.new(nodes.map(&:id))
      index = Hash.new { |h, k| h[k] = {} }

      nodes.each_with_object({}) do |node, arranged|
        index[node.parent_id][node] = children = index[node.id]
        if node.parent_id.nil?
          arranged[node] = children
        elsif !node_ids.include?(node.parent_id)
          case orphan_strategy
          when :destroy
             # All children are destroyed as well (default)
          when :adopt
            raise ArgumentError, "Not Implemented"
          when :rootify
            arranged[node] = children
          when :restrict
            raise Ancestry::AncestryException, I18n.t("ancestry.cannot_delete_descendants")
          end
        end
      end
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
