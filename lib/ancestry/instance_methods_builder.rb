# frozen_string_literal: true

module Ancestry
  # Builds a named module with ancestry instance methods.
  # Column names and format module are baked into the method bodies as string literals.
  # The module can be reused across models with the same (format, column, delimiter) configuration.
  module InstanceMethodsBuilder
    # @param format_module [Module] MaterializedPath or MaterializedPath2
    # @param column [Symbol] the ancestry column name (e.g., :ancestry)
    # @param delimiter [String] the path delimiter (e.g., "/")
    # @param root [nil, String] the root value (nil for mp1, "/" for mp2)
    # @return [Module] a named module with baked-in instance methods
    def self.build(format_module, column, delimiter, root)
      format_name = format_module.name.split("::").last
      mod_name = :"#{format_name}_#{column}"

      if Ancestry.const_defined?(mod_name, false)
        return Ancestry.const_get(mod_name, false)
      end

      mod = Module.new
      Ancestry.const_set(mod_name, mod)

      # Note: primary_key_is_an_integer? requires DB introspection so it cannot be
      # baked in at module definition time. It is resolved lazily via self.class.
      mod.class_eval <<~RUBY, __FILE__, __LINE__ + 1
        # optimization - better to go directly to column and avoid parsing
        def ancestors?
          read_attribute(:#{column}) != #{root.inspect}
        end
        alias has_parent? ancestors?

        def ancestor_ids=(value)
          write_attribute(:#{column}, #{format_module}.generate(value, "#{delimiter}", #{root.inspect}))
        end

        def ancestor_ids
          Ancestry::MaterializedPath.parse(read_attribute(:#{column}), #{root.inspect}, "#{delimiter}", self.class.primary_key_is_an_integer?)
        end

        def ancestor_ids_in_database
          Ancestry::MaterializedPath.parse(attribute_in_database(:#{column}), #{root.inspect}, "#{delimiter}", self.class.primary_key_is_an_integer?)
        end

        def ancestor_ids_before_last_save
          Ancestry::MaterializedPath.parse(attribute_before_last_save(:#{column}), #{root.inspect}, "#{delimiter}", self.class.primary_key_is_an_integer?)
        end

        def parent_id_in_database
          Ancestry::MaterializedPath.parse(attribute_in_database(:#{column}), #{root.inspect}, "#{delimiter}", self.class.primary_key_is_an_integer?).last
        end

        def parent_id_before_last_save
          Ancestry::MaterializedPath.parse(attribute_before_last_save(:#{column}), #{root.inspect}, "#{delimiter}", self.class.primary_key_is_an_integer?).last
        end

        # optimization - better to go directly to column and avoid parsing
        def sibling_of?(node)
          read_attribute(:#{column}) == node.read_attribute(:#{column})
        end

        def child_ancestry
          raise(Ancestry::AncestryException, I18n.t("ancestry.no_child_for_new_record")) if new_record?

          #{format_module}.child_ancestry_value(attribute_in_database(:#{column}), id, "#{delimiter}")
        end

        def child_ancestry_before_last_save
          if new_record? || (respond_to?(:previously_new_record?) && previously_new_record?)
            raise Ancestry::AncestryException, I18n.t("ancestry.no_child_for_new_record")
          end

          #{format_module}.child_ancestry_value(attribute_before_last_save(:#{column}), id, "#{delimiter}")
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

        def children
          self.class.ancestry_base_class.children_of(self)
        end

        def child_ids
          children.pluck(self.class.primary_key)
        end

        def has_children?
          children.exists?
        end
        alias children? has_children?

        def is_childless?
          !has_children?
        end
        alias childless? is_childless?

        def siblings
          self.class.ancestry_base_class.siblings_of(self).where.not(self.class.primary_key => id)
        end

        def sibling_ids
          siblings.pluck(self.class.primary_key)
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
          descendants(depth_options).pluck(self.class.primary_key)
        end

        def indirects(depth_options = {})
          self.class.ancestry_base_class.ordered_by_ancestry.scope_depth(depth_options, depth).indirects_of(self)
        end

        def indirect_ids(depth_options = {})
          indirects(depth_options).pluck(self.class.primary_key)
        end

        def subtree(depth_options = {})
          self.class.ancestry_base_class.ordered_by_ancestry.scope_depth(depth_options, depth).subtree_of(self)
        end

        def subtree_ids(depth_options = {})
          subtree(depth_options).pluck(self.class.primary_key)
        end

        # Parent

        def parent=(parent)
          self.ancestor_ids = parent ? parent.path_ids : []
        end

        def parent_id=(new_parent_id)
          self.parent = new_parent_id.present? ? unscoped_find(new_parent_id) : nil
        end

        def parent
          if has_parent?
            unscoped_where do |scope|
              scope.find_by scope.primary_key => parent_id
            end
          end
        end

        # Root

        def root
          if has_parent?
            unscoped_where { |scope| scope.find_by(scope.primary_key => root_id) } || self
          else
            self
          end
        end

        # Validate that descendants' depths don't exceed max depth when moving them
        def ancestry_depth_of_descendants
          return if new_record? || (respond_to?(:previously_new_record?) && previously_new_record?)
          return unless self.class.respond_to?(:depth_cache_column) && self.class.depth_cache_column

          depth_col = self.class.depth_cache_column
          validator = self.class.validators_on(depth_col).find do |v|
            v.is_a?(ActiveModel::Validations::NumericalityValidator) &&
              (v.options[:less_than_or_equal_to] || v.options[:less_than])
          end
          return unless validator

          max_depth = validator.options[:less_than_or_equal_to] || (validator.options[:less_than] - 1)

          old_value = attribute_in_database(:#{column})
          new_value = read_attribute(:#{column})
          depth_change = self.class.ancestry_depth_change(old_value, new_value)

          if depth_change > 0
            max_descendant_depth = unscoped_descendants.maximum(depth_col) || attribute_in_database(depth_col) || 0
            if max_descendant_depth + depth_change > max_depth
              errors.add(depth_col, :less_than_or_equal_to, count: max_depth)
            end
          end
        end

        def cache_depth
          write_attribute self.class.ancestry_base_class.depth_cache_column, depth
        end

        # Update descendants with new ancestry using a single SQL statement
        def update_descendants_with_new_ancestry_sql
          if !ancestry_callbacks_disabled? && sane_ancestor_ids?
            old_ancestry = self.class.generate_ancestry(path_ids_before_last_save)
            new_ancestry = self.class.generate_ancestry(path_ids)
            adapter = self.class.connection.adapter_name.downcase
            replace_sql = Ancestry::MaterializedPath.concat(adapter, "'\#{new_ancestry}'", "SUBSTRING(#{column}, \#{old_ancestry.length + 1})")
            update_clause = {
              :#{column} => Arel.sql(replace_sql)
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
          if self.class.respond_to?(:depth_cache_column)
            depth_cache_column = self.class.depth_cache_column
            depth_change = self.class.ancestry_depth_change(old_ancestry, new_ancestry)

            if depth_change != 0
              update_clause[depth_cache_column] = Arel.sql("\#{depth_cache_column} + \#{depth_change}")
            end
          end
          update_clause
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
          where(arel_table[primary_key].in(node.ancestor_ids))
        end

        def inpath_of(object)
          node = to_node(object)
          where(arel_table[primary_key].in(node.path_ids))
        end

        def children_of(object)
          node = to_node(object)
          where(arel_table[:#{column}].eq(node.child_ancestry))
        end

        def indirects_of(object)
          node = to_node(object)
          where(#{format_module}.indirects_condition(arel_table[:#{column}], node.child_ancestry, "#{delimiter}"))
        end

        def descendants_of(object)
          where(descendant_conditions(object))
        end

        def descendants_by_ancestry(ancestry)
          #{format_module}.descendants_condition(arel_table[:#{column}], ancestry, "#{delimiter}")
        end

        def descendant_conditions(object)
          node = to_node(object)
          descendants_by_ancestry(node.child_ancestry)
        end

        def descendant_before_last_save_conditions(object)
          node = to_node(object)
          descendants_by_ancestry(node.child_ancestry_before_last_save)
        end

        def subtree_of(object)
          node = to_node(object)
          descendants_of(node).or(where(arel_table[primary_key].eq(node.id)))
        end

        def siblings_of(object)
          node = to_node(object)
          where(arel_table[:#{column}].eq(node[#{column.inspect}].presence))
        end

        def ordered_by_ancestry(order = nil)
          #{_ordered_by_ancestry_body(format_module, column)}
        end

        def ordered_by_ancestry_and(order)
          ordered_by_ancestry(order)
        end

        def child_ancestry_sql
          #{format_module}.child_ancestry_sql(table_name, #{column.inspect}, primary_key, "#{delimiter}", connection.adapter_name.downcase)
        end

        def ancestry_depth_sql
          @ancestry_depth_sql ||= #{format_module}.construct_depth_sql(table_name, #{column.inspect}, "#{delimiter}")
        end

        def generate_ancestry(ancestor_ids)
          #{format_module}.generate(ancestor_ids, "#{delimiter}", #{root.inspect})
        end

        def parse_ancestry_column(obj)
          Ancestry::MaterializedPath.parse(obj, #{root.inspect}, "#{delimiter}", primary_key_is_an_integer?)
        end

        def ancestry_depth_change(old_value, new_value)
          parse_ancestry_column(new_value).size - parse_ancestry_column(old_value).size
        end

        def ancestry_primary_key_format
          Ancestry.default_primary_key_format
        end

        def ancestry_validation_options(ancestry_primary_key_format)
          #{format_module}.validation_options(ancestry_primary_key_format, "#{delimiter}")
        end

        def sort_by_ancestry(nodes, &block)
          Ancestry::ClassMethods._sort_by_ancestry(self, nodes, :#{column}, &block)
        end

        def check_ancestry_integrity!(options = {})
          Ancestry::ClassMethods._check_ancestry_integrity!(self, :#{column}, options)
        end

        def rebuild_counter_cache!
          Ancestry::ClassMethods._rebuild_counter_cache!(self, :#{column})
        end
      RUBY

      mod
    end

    # Generate the ordered_by_ancestry method body based on format
    def self._ordered_by_ancestry_body(format_module, column)
      if format_module == Ancestry::MaterializedPath2
        <<~BODY.strip
          reorder(Arel::Nodes::Ascending.new(arel_table[:#{column}]), order)
        BODY
      else
        <<~BODY.strip
          if %w(mysql mysql2 sqlite sqlite3).include?(connection.adapter_name.downcase)
            reorder(arel_table[:#{column}], order)
          elsif %w(postgresql oracleenhanced).include?(connection.adapter_name.downcase) && ActiveRecord::VERSION::STRING >= "6.1"
            reorder(Arel::Nodes::Ascending.new(arel_table[:#{column}]).nulls_first, order)
          else
            reorder(
              Arel::Nodes::Ascending.new(Arel::Nodes::NamedFunction.new('COALESCE', [arel_table[:#{column}], Arel.sql("''")])),
              order
            )
          end
        BODY
      end
    end
  end
end
