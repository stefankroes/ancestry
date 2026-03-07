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

        def cache_depth
          write_attribute self.class.ancestry_base_class.depth_cache_column, depth
        end
      RUBY

      mod
    end
  end
end
