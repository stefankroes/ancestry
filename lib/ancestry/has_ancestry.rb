module Ancestry
  module HasAncestry
    def has_ancestry options = {}
      # Check options
      raise Ancestry::AncestryException.new(I18n.t("ancestry.option_must_be_hash")) unless options.is_a? Hash
      options.each do |key, value|
        unless [:ancestry_column, :orphan_strategy, :cache_depth, :depth_cache_column, :touch, :counter_cache, :primary_key_format, :update_strategy].include? key
          raise Ancestry::AncestryException.new(I18n.t("ancestry.unknown_option", {:key => key.inspect, :value => value.inspect}))
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

      pattern = options[:primary_key_format] || /\A[0-9]+\Z/ #(pi ? /\A[0-9]+\Z/ : /\A[^\/]\Z/) # ANCESTRY_DELIMITER

      pi = "a" !~ pattern # want to know primary_key_is_an_integer? without accessing the database


      attribute ancestry_column, :materialized_path_string, :casting => pi ? :to_i : :to_s, :delimiter => '/'
      validates ancestry_column, :array_pattern => {:id => true, :pattern => pattern, :integer => pi}
      alias_attribute :ancestor_ids, ancestry_column
      if ActiveRecord::VERSION::STRING < '5.1.0'
        alias_method :ancestor_ids_before_last_save, :ancestor_ids_was
        alias_method :ancestor_ids_in_database, :ancestor_ids_was
        # usable in after save hook
        # monkey patching will_save_change to fix rails 
        alias_method :saved_change_to_ancestor_ids?, :will_save_change_to_ancestor_ids?
        alias_method :will_save_change_to_ancestor_ids?, :will_save_change_to_ancestor_ids?
      end

      extend Ancestry::MaterializedPath

      update_strategy = options[:update_strategy] || Ancestry.default_update_strategy
      include Ancestry::MaterializedPathPg if update_strategy == :sql

      # Create orphan strategy accessor and set to option or default (writer comes from DynamicClassMethods)
      cattr_reader :orphan_strategy
      self.orphan_strategy = options[:orphan_strategy] || :destroy

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

        after_create :increase_parent_counter_cache, if: :ancestor_ids?
        after_destroy :decrease_parent_counter_cache, if: :ancestor_ids?
        after_update :update_parent_counter_cache
      end

      # Create named scopes for depth
      {:before_depth => '<', :to_depth => '<=', :at_depth => '=', :from_depth => '>=', :after_depth => '>'}.each do |scope_name, operator|
        scope scope_name, lambda { |depth|
          raise Ancestry::AncestryException.new(I18n.t("ancestry.named_scope_depth_cache",
                                                       :scope_name => scope_name
                                                       )) unless options[:cache_depth]
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
  extend Ancestry::HasAncestry
end
