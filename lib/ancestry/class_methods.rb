# frozen_string_literal: true

module Ancestry
  module ClassMethods
    # Fetch tree node if necessary
    def to_node(object)
      if object.is_a?(ancestry_base_class)
        object
      else
        unscoped_where { |scope| scope.find_by!(primary_ancestry_key => object.try(primary_ancestry_key) || object) }
      end
    end

    # Scope on relative depth options
    # Writes depth constraints directly against depth_cache_sql rather than
    # dispatching through the 5 named scopes.
    DEPTH_OPERATORS = {
      before_depth: '<',
      to_depth:     '<=',
      at_depth:     '=',
      from_depth:   '>=',
      after_depth:  '>',
    }.freeze

    def scope_depth(depth_options, depth)
      depth_sql = ancestry_depth_sql
      depth_options.inject(ancestry_base_class) do |scope, (scope_name, relative_depth)|
        operator = DEPTH_OPERATORS[scope_name]
        raise Ancestry::AncestryException, I18n.t("ancestry.unknown_depth_option", scope_name: scope_name) unless operator
        scope.where("#{depth_sql} #{operator} ?", depth + relative_depth)
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
      node_ids = Set.new(nodes.map(&:ancestry_id))
      index = Hash.new { |h, k| h[k] = {} }

      if orphan_strategy == :rootify
        nodes.each_with_object({}) do |node, arranged|
          index[node.parent_id][node] = children = index[node.ancestry_id]
          arranged[node] = children unless node_ids.include?(node.parent_id)
        end
      else
        nodes.each_with_object({}) do |node, arranged|
          index[node.parent_id][node] = children = index[node.ancestry_id]
          if node.parent_id.nil?
            arranged[node] = children
          elsif !node_ids.include?(node.parent_id)
            case orphan_strategy
            when :destroy
              # silently drop orphaned nodes and their children
            when :restrict
              raise Ancestry::AncestryException, I18n.t("ancestry.cannot_delete_descendants")
            end
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

    def tree_view(column, data = nil, &block)
      block ||= method(:puts)
      data ||= arrange
      data.each do |parent, children|
        if parent.depth == 0
          block.call parent[column]
        else
          num = parent.depth - 1
          indent = "   " * num
          block.call " #{"|" if parent.depth > 1}#{indent}|_ #{parent[column]}"
        end
        tree_view(column, children, &block) if children
      end
    end

    # Pseudo-preordered array of nodes.  Children will always follow parents,
    # This is deterministic unless the parents are missing *and* a sort block is specified
    def self._sort_by_ancestry(klass, nodes, column, &block)
      arranged = nodes if nodes.is_a?(Hash)

      unless arranged
        presorted_nodes = nodes.sort do |a, b|
          rank = (a.public_send(column) || ' ') <=> (b.public_send(column) || ' ')
          rank = block.call(a, b) if rank == 0 && block
          rank
        end

        arranged = klass.arrange_nodes(presorted_nodes)
      end

      klass.flatten_arranged_nodes(arranged)
    end

    # Integrity checking
    # compromised tree integrity is unlikely without explicitly setting cyclic parents or invalid ancestry and circumventing validation
    # just in case, raise an AncestryIntegrityException if issues are detected
    # specify :report => :list to return an array of exceptions or :report => :echo to echo any error messages
    def self._check_ancestry_integrity!(klass, column, options = {})
      parents = {}
      exceptions = [] if options[:report] == :list

      klass.unscoped_where do |scope|
        # For each node ...
        scope.find_each do |node|
          # ... check validity of ancestry column
          if !node.sane_ancestor_ids?
            raise Ancestry::AncestryIntegrityException, I18n.t("ancestry.invalid_ancestry_column",
                                                               :node_id => node.ancestry_id,
                                                               :ancestry_column => node.read_attribute(column))
          end
          # ... check that all ancestors exist
          node.ancestor_ids.each do |ancestor_id|
            unless klass.exists?(klass.primary_ancestry_key => ancestor_id)
              raise Ancestry::AncestryIntegrityException, I18n.t("ancestry.reference_nonexistent_node",
                                                                 :node_id => node.ancestry_id,
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
            parent_ids[node.ancestry_id] = node.parent_id if exists?(primary_ancestry_key => node.parent_id)

            # Reset parent id in array to nil if it introduces a cycle
            parent_id = parent_ids[node.ancestry_id]
            until parent_id.nil? || parent_id == node.ancestry_id
              parent_id = parent_ids[parent_id]
            end
            parent_ids[node.ancestry_id] = nil if parent_id == node.ancestry_id
          end

          # For each node ...
          scope.find_each do |node|
            # ... rebuild ancestry from parent_ids array
            ancestor_ids, parent_id = [], parent_ids[node.ancestry_id]
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
          build_ancestry_from_parent_ids! column, node.ancestry_id, ancestor_ids + [node.ancestry_id]
        end
      end
    end

    def self._rebuild_depth_cache!(klass, depth_cache_column)
      klass.ancestry_base_class.transaction do
        klass.unscoped_where do |scope|
          scope.find_each do |node|
            node.update_attribute depth_cache_column, node.depth
          end
        end
      end
    end

    def self._rebuild_root_id_cache!(klass, root_cache_column)
      klass.ancestry_base_class.transaction do
        klass.unscoped_where do |scope|
          scope.find_each do |node|
            node.update_attribute root_cache_column, node.root_id
          end
        end
      end
    end

    def self._rebuild_parent_id_cache!(klass, parent_cache_column)
      klass.ancestry_base_class.transaction do
        klass.unscoped_where do |scope|
          scope.find_each do |node|
            node.update_attribute parent_cache_column, node.parent_id
          end
        end
      end
    end

    # Rebuild counter cache for all nodes.
    #
    # When verbose is true, returns the number of rows that had incorrect
    # counter values (inspired by counter_culture gem's fix_counts).
    #
    # @param verbose [Boolean] when true, count incorrect rows before fixing
    # @return [Integer, nil] number of corrected rows when verbose, nil otherwise
    def self._rebuild_counter_cache!(klass, column, counter_col, verbose: false)
      child_sql = klass.child_ancestry_sql
      tbl = klass.table_name
      pk = klass.primary_ancestry_key

      fixed =
        if verbose
          klass.ancestry_base_class.default_scoped.unscope(:where).where(
            "#{counter_col} != (SELECT COUNT(*) FROM #{tbl} children WHERE children.#{column} = (#{child_sql}))"
          ).count
        end

      if %w(mysql mysql2 trilogy).include?(klass.connection.adapter_name.downcase)
        klass.connection.execute %{
          UPDATE #{tbl} AS dest
          LEFT JOIN (
            SELECT #{tbl}.#{pk}, COUNT(*) AS child_count
            FROM #{tbl}
            JOIN #{tbl} children ON children.#{column} = (#{child_sql})
            GROUP BY #{tbl}.#{pk}
          ) src USING(#{pk})
          SET dest.#{counter_col} = COALESCE(src.child_count, 0)
        }
      else
        klass.update_all %{
          #{counter_col} = (
            SELECT COUNT(*)
            FROM #{tbl} children
            WHERE children.#{column} = (#{child_sql})
          )
        }
      end

      fixed
    end

    # Static helpers for callback methods.
    # Builder generates thin wrappers that delegate here with baked-in column.

    def self._ancestry_exclude_self(record)
      record.errors.add(:base, I18n.t("ancestry.exclude_self", class_name: record.class.model_name.human)) if record.ancestor_ids.include?(record.ancestry_id)
    end

    def self._update_descendants_with_new_ancestry(record)
      return if record.ancestry_callbacks_disabled? || !record.sane_ancestor_ids?

      record.send(:unscoped_descendants_before_last_save).each do |descendant|
        descendant.without_ancestry_callbacks do
          new_ancestor_ids = record.path_ids + (descendant.ancestor_ids - record.path_ids_before_last_save)
          descendant.update_attribute(:ancestor_ids, new_ancestor_ids)
        end
      end
    end

    def self._apply_orphan_strategy_rootify(record)
      return if record.ancestry_callbacks_disabled? || record.new_record?

      record.send(:unscoped_descendants).each do |descendant|
        descendant.without_ancestry_callbacks do
          descendant.update_attribute :ancestor_ids, descendant.ancestor_ids - record.path_ids
        end
      end
    end

    def self._apply_orphan_strategy_destroy(record)
      return if record.ancestry_callbacks_disabled? || record.new_record?

      record.send(:unscoped_descendants).ordered_by_ancestry.reverse_order.each do |descendant|
        descendant.without_ancestry_callbacks do
          descendant.destroy
        end
      end
    end

    def self._apply_orphan_strategy_adopt(record)
      return if record.ancestry_callbacks_disabled? || record.new_record?

      record.class.ancestry_base_class.descendants_of(record).each do |descendant|
        descendant.without_ancestry_callbacks do
          descendant.update_attribute :ancestor_ids, descendant.ancestor_ids - [record.ancestry_id]
        end
      end
    end

    def self._apply_orphan_strategy_restrict(record)
      return if record.ancestry_callbacks_disabled? || record.new_record?

      raise(Ancestry::AncestryException, I18n.t("ancestry.cannot_delete_descendants")) unless record.is_childless?
    end

    def self._touch_ancestors_callback(record)
      return if record.ancestry_callbacks_disabled?

      record.send(:unscoped_current_and_previous_ancestors).each do |ancestor|
        ancestor.without_ancestry_callbacks do
          ancestor.touch
        end
      end
    end

    def unscoped_where
      yield ancestry_base_class.default_scoped.unscope(:where)
    end
  end
end
