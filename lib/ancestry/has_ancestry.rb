module Ancestry
  module HasAncestry
    def has_ancestry options = {}
      # Check options
      raise Ancestry::AncestryException.new("Options for has_ancestry must be in a hash.") unless options.is_a? Hash
      options.each do |key, value|
        unless [:ancestry_column, :orphan_strategy, :cache_depth, :depth_cache_column, :touch, :counter_cache].include? key
          raise Ancestry::AncestryException.new("Unknown option for has_ancestry: #{key.inspect} => #{value.inspect}.")
        end
      end

      # Create ancestry column accessor and set to option or default
      cattr_accessor :ancestry_column
      self.ancestry_column = options[:ancestry_column] || :ancestry

      # Save self as base class (for STI)
      cattr_accessor :ancestry_base_class
      self.ancestry_base_class = self

      # Touch ancestors after updating
      cattr_accessor :touch_ancestors
      self.touch_ancestors = options[:touch] || false

      # Include instance methods
      include Ancestry::InstanceMethods

      # Include dynamic class methods
      extend Ancestry::ClassMethods

      extend Ancestry::MaterializedPath

      # Create orphan strategy accessor and set to option or default (writer comes from DynamicClassMethods)
      cattr_reader :orphan_strategy
      self.orphan_strategy = options[:orphan_strategy] || :destroy

      # Validate that the ancestor ids don't include own id
      validate :ancestry_exclude_self

      # Named scopes
      scope :roots, lambda { where(root_conditions) }
      scope :ancestors_of, lambda { |object| where(ancestor_conditions(object)) }
      scope :children_of, lambda { |object| where(child_conditions(object)) }
      scope :indirects_of, lambda { |object| where(indirect_conditions(object)) }
      scope :descendants_of, lambda { |object| where(descendant_conditions(object)) }
      scope :subtree_of, lambda { |object| where(subtree_conditions(object)) }
      scope :siblings_of, lambda { |object| where(sibling_conditions(object)) }
      scope :ordered_by_ancestry, Proc.new { |order|
        if %w(mysql mysql2 sqlite sqlite3 postgresql).include?(connection.adapter_name.downcase) && ActiveRecord::VERSION::MAJOR >= 5
          reorder(
            Arel::Nodes::Ascending.new(Arel::Nodes::NamedFunction.new('COALESCE', [arel_table[ancestry_column], Arel.sql("''")])),
            order
          )
        else
          reorder(Arel.sql("(CASE WHEN #{connection.quote_table_name(table_name)}.#{connection.quote_column_name(ancestry_column)} IS NULL THEN 0 ELSE 1 END), #{connection.quote_table_name(table_name)}.#{connection.quote_column_name(ancestry_column)}"), order)
        end
      }
      scope :ordered_by_ancestry_and, Proc.new { |order| ordered_by_ancestry(order) }
      scope :path_of, lambda { |object| to_node(object).path }

      # Update descendants with new ancestry before save
      before_save :update_descendants_with_new_ancestry

      # Apply orphan strategy before destroy
      before_destroy :apply_orphan_strategy

      # Create ancestry column accessor and set to option or default
      if options[:cache_depth]
        # Create accessor for column name and set to option or default
        self.cattr_accessor :depth_cache_column
        self.depth_cache_column = options[:depth_cache_column] || :ancestry_depth

        # Cache depth in depth cache column before save
        before_validation :cache_depth
        before_save :cache_depth

        # Validate depth column
        validates_numericality_of depth_cache_column, :greater_than_or_equal_to => 0, :only_integer => true, :allow_nil => false
      end

      # Create counter cache column accessor and set to option or default
      if options[:counter_cache]
        cattr_accessor :counter_cache_column

        if options[:counter_cache] == true
          self.counter_cache_column = :children_count
        else
          self.counter_cache_column = options[:counter_cache]
        end

        after_create :increase_parent_counter_cache, if: :has_parent?
        after_destroy :decrease_parent_counter_cache, if: :has_parent?
        after_update :update_parent_counter_cache
      end

      # Create named scopes for depth
      {:before_depth => '<', :to_depth => '<=', :at_depth => '=', :from_depth => '>=', :after_depth => '>'}.each do |scope_name, operator|
        scope scope_name, lambda { |depth|
          raise Ancestry::AncestryException.new("Named scope '#{scope_name}' is only available when depth caching is enabled.") unless options[:cache_depth]
          where("#{depth_cache_column} #{operator} ?", depth)
        }
      end

      after_touch :touch_ancestors_callback
      after_destroy :touch_ancestors_callback

      if ActiveRecord::VERSION::STRING >= '5.1.0'
        after_save :touch_ancestors_callback, if: :saved_changes?
      else
        after_save :touch_ancestors_callback, if: :changed?
      end
    end

    def acts_as_tree(*args)
      return super if defined?(super)
      has_ancestry(*args)
    end
  end
end

ActiveSupport.on_load :active_record do
  send :extend, Ancestry::HasAncestry
end
