# frozen_string_literal: true

module Ancestry
  # Builds a named module with ancestry instance methods.
  # Column names and format module are baked into the method bodies as string literals.
  # The module can be reused across models with the same (format, column) configuration.
  module InstanceMethodsBuilder
    # @param format_module [Module] MaterializedPath or MaterializedPath2
    # @param column [Symbol] the ancestry column name (e.g., :ancestry)
    # @param root [nil, String] the root value (nil for mp1, "/" for mp2)
    # @param depth_cache_column [String, nil] column name for depth cache, or nil
    # @param counter_cache_column [String, nil] column name for counter cache, or nil
    # @param parent_cache_column [String, nil] column name for parent cache, or nil
    # @param root_cache_column [String, nil] column name for root cache, or nil
    # @return [Module] a named module with baked-in instance methods
    def self.build(format_module, column, root, primary_key: :id, integer_pk: nil, depth_cache_column: nil, counter_cache_column: nil, parent_cache_column: nil, root_cache_column: nil, parent_association: false, root_association: false)
      pk = primary_key
      parse_method = integer_pk ? :parse_integer : :parse
      format_name = format_module.name.split("::").last
      mod_name = [
        format_name,
        column,
        ("pk#{pk}" unless pk == :id),
        ("ipk" if integer_pk),
        ("d#{depth_cache_column}" if depth_cache_column),
        ("c#{counter_cache_column}" if counter_cache_column),
        ("p#{parent_cache_column}" if parent_cache_column),
        ("r#{root_cache_column}" if root_cache_column),
        ("ap" if parent_association),
        ("ar" if root_association),
      ].compact.join("_").to_sym

      if Ancestry.const_defined?(mod_name, false)
        return Ancestry.const_get(mod_name, false)
      end

      mod = Module.new
      Ancestry.const_set(mod_name, mod)

      mod.class_eval <<~RUBY, __FILE__, __LINE__ + 1
        # optimization - better to go directly to column and avoid parsing
        def ancestors?
          read_attribute(:#{column}) != #{root.inspect}
        end
        alias has_parent? ancestors?

        def ancestor_ids=(value)
          @_ancestor_ids = value.freeze
          write_attribute(:#{column}, #{format_module}.generate(value))
          #{"ancestry_sync_parent_cache(#{parent_cache_column.inspect}, value)" if parent_cache_column || parent_association}
          #{"ancestry_sync_root_cache(#{root_cache_column.inspect}, value)" if root_cache_column || root_association}
        end

        def ancestor_ids
          @_ancestor_ids ||= #{format_module}.#{parse_method}(read_attribute(:#{column})).freeze
        end

        def reload(*)
          @_ancestor_ids = nil
          super
        end

        def ancestor_ids_in_database
          #{format_module}.#{parse_method}(attribute_in_database(:#{column}))
        end

        def ancestor_ids_before_last_save
          #{format_module}.#{parse_method}(attribute_before_last_save(:#{column}))
        end

        def parent_id_in_database
          #{format_module}.#{parse_method}(attribute_in_database(:#{column})).last
        end

        def parent_id_before_last_save
          #{format_module}.#{parse_method}(attribute_before_last_save(:#{column})).last
        end

        # optimization - better to go directly to column and avoid parsing
        def sibling_of?(node)
          read_attribute(:#{column}) == node.read_attribute(:#{column})
        end

        def child_ancestry
          raise(Ancestry::AncestryException, I18n.t("ancestry.no_child_for_new_record")) if new_record?

          #{format_module}.child_ancestry_value(attribute_in_database(:#{column}), id)
        end

        def child_ancestry_before_last_save
          if new_record? || (respond_to?(:previously_new_record?) && previously_new_record?)
            raise Ancestry::AncestryException, I18n.t("ancestry.no_child_for_new_record")
          end

          #{format_module}.child_ancestry_value(attribute_before_last_save(:#{column}), id)
        end

        def ancestry_changed?
          !!(will_save_change_to_attribute?(:#{column}) || saved_change_to_attribute?(:#{column}))
        end

        def sane_ancestor_ids?
          current_context, self.validation_context = validation_context, nil
          errors.clear

          ancestry_value = read_attribute(:#{column})
          return true unless ancestry_value

          self.class.validators_on(:#{column}).each do |validator|
            validator.validate_each(self, :#{column}, ancestry_value)
          end
          ancestry_exclude_self
          errors.none?
        ensure
          self.validation_context = current_context
        end

        # Navigation

        def parent_id
          ancestor_ids.last if has_parent?
        end
        alias parent_id? ancestors?

        def root_id
          has_parent? ? ancestor_ids.first : id
        end

        def depth
          ancestor_ids.size
        end

        def is_root?
          !has_parent?
        end
        alias root? is_root?

        def path_ids
          ancestor_ids + [id]
        end

        def path_ids_before_last_save
          ancestor_ids_before_last_save + [id]
        end

        def path_ids_in_database
          ancestor_ids_in_database + [id]
        end

        # Predicates

        def ancestor_of?(node)
          node.ancestor_ids.include?(id)
        end

        def parent_of?(node)
          id == node.parent_id
        end

        def child_of?(node)
          parent_id == node.id
        end

        def root_of?(node)
          id == node.root_id
        end

        def descendant_of?(node)
          ancestor_ids.include?(node.id)
        end

        def indirect_of?(node)
          ancestor_ids[0..-2].include?(node.id)
        end

        def in_subtree_of?(node)
          id == node.id || descendant_of?(node)
        end

        # Scope-delegating navigation methods

        def ancestors(depth_options = {})
          return self.class.ancestry_base_class.none unless has_parent?

          self.class.ancestry_base_class.scope_depth(depth_options, depth).ordered_by_ancestry.ancestors_of(self)
        end

        def path(depth_options = {})
          self.class.ancestry_base_class.scope_depth(depth_options, depth).ordered_by_ancestry.inpath_of(self)
        end

        #{ if parent_association
          <<~RUBY
            def child_ids
              children.pluck(:#{pk})
            end

            def has_children?
              children.exists?
            end
            alias children? has_children?

            def is_childless?
              !has_children?
            end
            alias childless? is_childless?
          RUBY
        else
          <<~RUBY
            def children
              self.class.ancestry_base_class.children_of(self)
            end

            def child_ids
              children.pluck(:#{pk})
            end

            def has_children?
              children.exists?
            end
            alias children? has_children?

            def is_childless?
              !has_children?
            end
            alias childless? is_childless?
          RUBY
        end}

        alias leaf? is_childless?

        def leaves(depth_options = {})
          self.class.ancestry_base_class.scope_depth(depth_options, depth).leaves_of(self)
        end

        def leaf_ids(depth_options = {})
          leaves(depth_options).pluck(:#{pk})
        end

        def siblings
          self.class.ancestry_base_class.siblings_of(self).where.not(:#{pk} => id)
        end

        def sibling_ids
          siblings.pluck(:#{pk})
        end

        def has_siblings?
          siblings.exists?
        end
        alias siblings? has_siblings?

        def is_only_child?
          !has_siblings?
        end
        alias only_child? is_only_child?

        def descendants(depth_options = {})
          self.class.ancestry_base_class.ordered_by_ancestry.scope_depth(depth_options, depth).descendants_of(self)
        end

        def descendant_ids(depth_options = {})
          descendants(depth_options).pluck(:#{pk})
        end

        def indirects(depth_options = {})
          self.class.ancestry_base_class.ordered_by_ancestry.scope_depth(depth_options, depth).indirects_of(self)
        end

        def indirect_ids(depth_options = {})
          indirects(depth_options).pluck(:#{pk})
        end

        def subtree(depth_options = {})
          self.class.ancestry_base_class.ordered_by_ancestry.scope_depth(depth_options, depth).subtree_of(self)
        end

        def subtree_ids(depth_options = {})
          subtree(depth_options).pluck(:#{pk})
        end

        # Parent

        def parent=(parent)
          self.ancestor_ids = parent ? parent.path_ids : []
          #{ if parent_association
            "association(:parent).target = parent"
          end}
        end

        def parent_id=(new_parent_id)
          self.parent = new_parent_id.present? ? unscoped_find(new_parent_id) : nil
        end

        #{ if parent_association
          <<~RUBY
            def parent
              ancestry_lookup_parent if has_parent?
            end
          RUBY
        else
          <<~RUBY
            def parent
              if has_parent?
                unscoped_where { |scope| scope.find_by(:#{pk} => parent_id) }
              end
            end
          RUBY
        end}

        # Root

        #{ if root_association
          <<~RUBY
            def root
              has_parent? ? ancestry_lookup_root : self
            end
          RUBY
        else
          <<~RUBY
            def root
              if has_parent?
                unscoped_where { |scope| scope.find_by(:#{pk} => root_id) } || self
              else
                self
              end
            end
          RUBY
        end}

        #{ if depth_cache_column
          <<~RUBY
            def ancestry_depth_of_descendants
              return if new_record? || (respond_to?(:previously_new_record?) && previously_new_record?)
              validate_depth_of_descendants(:#{depth_cache_column}, self.class.ancestry_depth_change(attribute_in_database(:#{column}), read_attribute(:#{column})))
            end
          RUBY
        else
          <<~RUBY
            def ancestry_depth_of_descendants
            end
          RUBY
        end}

        #{ if depth_cache_column || parent_cache_column || root_cache_column
          <<~RUBY
            def cache_ancestry_columns
              #{"write_attribute :#{depth_cache_column}, depth" if depth_cache_column}
              #{"write_attribute :#{parent_cache_column}, parent_id" if parent_cache_column}
              #{"write_attribute :#{root_cache_column}, root_id" if root_cache_column}
            end
          RUBY
        end}

        #{ if root_cache_column
          <<~RUBY
            def cache_ancestry_columns_after_create
              new_root_id = root_id
              update_column :#{root_cache_column}, new_root_id if read_attribute(:#{root_cache_column}) != new_root_id
            end
          RUBY
        end}

        # Update descendants with new ancestry using a single SQL statement
        def update_descendants_with_new_ancestry_sql
          if !ancestry_callbacks_disabled? && sane_ancestor_ids?
            old_ancestry = self.class.generate_ancestry(path_ids_before_last_save)
            new_ancestry = self.class.generate_ancestry(path_ids)
            replace_sql = #{format_module}.replace_ancestry_sql(:#{column}, old_ancestry, new_ancestry, self.class)
            update_clause = {
              :#{column} => replace_sql
            }

            current_time = current_time_from_proper_timezone
            timestamp_attributes_for_update_in_model.each do |col|
              update_clause[col] = current_time
            end

            update_descendants_hook(update_clause, old_ancestry, new_ancestry)
            unscoped_descendants_before_last_save.update_all update_clause
          end
        end

        def update_descendants_hook(update_clause, old_ancestry, new_ancestry)
          #{"add_depth_cache_to_update_clause(update_clause, :#{depth_cache_column}, self.class.ancestry_depth_change(old_ancestry, new_ancestry))" if depth_cache_column}
          #{"add_root_cache_to_update_clause(update_clause, :#{root_cache_column})" if root_cache_column}
          update_clause
        end

        #{ if counter_cache_column
          <<~RUBY
            def increase_parent_counter_cache
              self.class.ancestry_base_class.increment_counter :#{counter_cache_column}, parent_id
            end

            def decrease_parent_counter_cache
              # TODO: remove when minimum Rails is 7.1+ (transaction rollback handles this)
              return if defined?(@_trigger_destroy_callback) && !@_trigger_destroy_callback
              return if ancestry_callbacks_disabled?
              self.class.ancestry_base_class.decrement_counter :#{counter_cache_column}, parent_id
            end

            def update_parent_counter_cache
              return unless ancestry_changed?
              if (parent_id_was = parent_id_before_last_save)
                self.class.ancestry_base_class.decrement_counter :#{counter_cache_column}, parent_id_was
              end
              parent_id && increase_parent_counter_cache
            end
          RUBY
        end}

        # Callback wrappers — delegate to static helpers in ClassMethods
        def ancestry_exclude_self
          Ancestry::ClassMethods._ancestry_exclude_self(self)
        end

        def update_descendants_with_new_ancestry
          Ancestry::ClassMethods._update_descendants_with_new_ancestry(self)
        end

        def apply_orphan_strategy_rootify
          Ancestry::ClassMethods._apply_orphan_strategy_rootify(self)
        end

        def apply_orphan_strategy_destroy
          Ancestry::ClassMethods._apply_orphan_strategy_destroy(self)
        end

        def apply_orphan_strategy_adopt
          Ancestry::ClassMethods._apply_orphan_strategy_adopt(self)
        end

        def apply_orphan_strategy_restrict
          Ancestry::ClassMethods._apply_orphan_strategy_restrict(self)
        end

        def touch_ancestors_callback
          Ancestry::ClassMethods._touch_ancestors_callback(self)
        end
      RUBY

      # Class methods submodule — auto-extended when the main module is included
      class_mod = Module.new
      mod.const_set(:ClassMethods, class_mod)

      mod.define_method(:included) do |base|
        base.extend(class_mod)
      end
      mod.send(:module_function, :included)

      class_mod.class_eval <<~RUBY, __FILE__, __LINE__ + 1
        def path_of(object)
          to_node(object).path
        end

        def roots
          where(arel_table[:#{column}].eq(#{root.inspect}))
        end

        def ancestors_of(object)
          node = to_node(object)
          where(arel_table[:#{pk}].in(node.ancestor_ids))
        end

        def inpath_of(object)
          node = to_node(object)
          where(arel_table[:#{pk}].in(node.path_ids))
        end

        def children_of(object)
          node = to_node(object)
          where(arel_table[:#{column}].eq(node.child_ancestry))
        end

        def indirects_of(object)
          node = to_node(object)
          where(#{format_module}.indirects_condition(arel_table[:#{column}], node.child_ancestry))
        end

        def descendants_of(object)
          node = to_node(object)
          where(#{format_module}.descendants_condition(arel_table[:#{column}], node.child_ancestry))
        end

        def descendant_conditions(object)
          node = to_node(object)
          #{format_module}.descendants_condition(arel_table[:#{column}], node.child_ancestry)
        end

        def descendant_before_last_save_conditions(object)
          node = to_node(object)
          #{format_module}.descendants_condition(arel_table[:#{column}], node.child_ancestry_before_last_save)
        end

        def subtree_of(object)
          node = to_node(object)
          descendants_of(node).or(where(arel_table[:#{pk}].eq(node.#{pk})))
        end

        def siblings_of(object)
          node = to_node(object)
          where(arel_table[:#{column}].eq(node[#{column.inspect}]#{ ".presence" if root.nil? }))
        end

        def leaves
          where("NOT EXISTS (SELECT 1 FROM \#{table_name} c WHERE c.#{column} = (\#{child_ancestry_sql}))")
        end

        def leaves_of(object)
          descendants_of(object).merge(leaves)
        end

        def ordered_by_ancestry(order = nil)
          reorder(#{format_module}.ordered_by_ancestry(arel_table[:#{column}], connection.adapter_name.downcase), order)
        end

        def ordered_by_ancestry_and(order)
          ordered_by_ancestry(order)
        end

        def child_ancestry_sql
          #{format_module}.child_ancestry_sql(table_name, #{column.inspect}, :#{pk}, connection.adapter_name.downcase, integer_pk: #{integer_pk.inspect})
        end

        def ancestry_depth_sql
          @ancestry_depth_sql ||= #{format_module}.construct_depth_sql(table_name, #{column.inspect})
        end

        def generate_ancestry(ancestor_ids)
          #{format_module}.generate(ancestor_ids)
        end

        def ancestry_depth_change(old_value, new_value)
          #{format_module}.#{parse_method}(new_value).size - #{format_module}.#{parse_method}(old_value).size
        end

        def ancestry_primary_key_format
          Ancestry.default_primary_key_format
        end

        def ancestry_validation_options(ancestry_primary_key_format)
          #{format_module}.validation_options(ancestry_primary_key_format)
        end

        def sort_by_ancestry(nodes, &block)
          Ancestry::ClassMethods._sort_by_ancestry(self, nodes, :#{column}, &block)
        end

        def check_ancestry_integrity!(options = {})
          Ancestry::ClassMethods._check_ancestry_integrity!(self, :#{column}, options)
        end

        #{ if counter_cache_column
          <<~RUBY
            def rebuild_counter_cache!(verbose: false)
              Ancestry::ClassMethods._rebuild_counter_cache!(self, :#{column}, :#{counter_cache_column}, verbose: verbose)
            end
          RUBY
        end}

        #{ if depth_cache_column
          <<~RUBY
            def rebuild_depth_cache!
              Ancestry::ClassMethods._rebuild_depth_cache!(self, :#{depth_cache_column})
            end

            def rebuild_depth_cache_sql!
              update_all("#{depth_cache_column} = \#{ancestry_depth_sql}")
            end
          RUBY
        else
          <<~RUBY
            def rebuild_depth_cache!
              raise Ancestry::AncestryException, I18n.t("ancestry.cannot_rebuild_depth_cache")
            end
          RUBY
        end}

        #{ if parent_cache_column
          <<~RUBY
            def ancestry_parent_id_sql
              @ancestry_parent_id_sql ||= #{format_module}.construct_parent_id_sql(table_name, #{column.inspect}, connection.adapter_name.downcase)
            end

            def rebuild_parent_id_cache!
              Ancestry::ClassMethods._rebuild_parent_id_cache!(self, :#{parent_cache_column})
            end

            def rebuild_parent_id_cache_sql!
              update_all("#{parent_cache_column} = (\#{ancestry_parent_id_sql})")
            end
          RUBY
        end}

        #{ if root_cache_column
          <<~RUBY
            def ancestry_root_id_sql
              @ancestry_root_id_sql ||= #{format_module}.construct_root_id_sql(table_name, #{column.inspect}, :#{pk}, connection.adapter_name.downcase)
            end

            def rebuild_root_id_cache!
              Ancestry::ClassMethods._rebuild_root_id_cache!(self, :#{root_cache_column})
            end

            def rebuild_root_id_cache_sql!
              update_all("#{root_cache_column} = (\#{ancestry_root_id_sql})")
            end
          RUBY
        end}
      RUBY

      mod
    end
  end
end
