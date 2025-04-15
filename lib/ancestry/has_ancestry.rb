# frozen_string_literal: true

module Ancestry
  module HasAncestry
    def has_ancestry(options = {})
      # Check options
      unless options.is_a? Hash
        raise Ancestry::AncestryException, I18n.t("ancestry.option_must_be_hash")
      end

      extra_keys = options.keys - [:ancestry_column, :orphan_strategy, :cache_depth, :depth_cache_column, :touch, :counter_cache, :primary_key_format, :update_strategy, :ancestry_format]
      if (key = extra_keys.first)
        raise Ancestry::AncestryException, I18n.t("ancestry.unknown_option", key: key.inspect, value: options[key].inspect)
      end

      ancestry_format = options[:ancestry_format] || Ancestry.default_ancestry_format
      if ![:materialized_path, :materialized_path2].include?(ancestry_format)
        raise Ancestry::AncestryException, I18n.t("ancestry.unknown_format", value: ancestry_format)
      end

      orphan_strategy = options[:orphan_strategy] || :destroy

      # Create ancestry column accessor and set to option or default
      class_variable_set('@@ancestry_column', options[:ancestry_column] || :ancestry)
      cattr_reader :ancestry_column, instance_reader: false

      primary_key_format = options[:primary_key_format].presence || Ancestry.default_primary_key_format

      class_variable_set('@@ancestry_delimiter', '/')
      cattr_reader :ancestry_delimiter, instance_reader: false

      # Save self as base class (for STI)
      class_variable_set('@@ancestry_base_class', self)
      cattr_reader :ancestry_base_class, instance_reader: false

      # Touch ancestors after updating
      # days are limited. need to handle touch in pg case
      cattr_accessor :touch_ancestors
      self.touch_ancestors = options[:touch] || false

      # Include instance methods
      include Ancestry::InstanceMethods
      include Ancestry::InstanceMethodsEager

      # Include dynamic class methods
      extend Ancestry::ClassMethods
      extend Ancestry::EagerLoading
      extend Ancestry::HasAncestry.ancestry_format_module(ancestry_format)

      attribute ancestry_column, default: ancestry_root

      validates ancestry_column, ancestry_validation_options(primary_key_format)

      update_strategy = options[:update_strategy] || Ancestry.default_update_strategy
      include Ancestry::MaterializedPathPg if update_strategy == :sql

      # Validate that the ancestor ids don't include own id
      validate :ancestry_exclude_self

      # Update descendants with new ancestry after update
      after_update :update_descendants_with_new_ancestry, if: :ancestry_changed?

      # Apply orphan strategy before destroy
      orphan_strategy_helper = "apply_orphan_strategy_#{orphan_strategy}"
      if method_defined?(orphan_strategy_helper)
        alias_method :apply_orphan_strategy, orphan_strategy_helper
        before_destroy :apply_orphan_strategy
      elsif orphan_strategy.to_s != "none"
        raise Ancestry::AncestryException, I18n.t("ancestry.invalid_orphan_strategy")
      end

      # Create ancestry column accessor and set to option or default
      
      if options[:cache_depth] == :virtual
        # NOTE: not setting self.depth_cache_column so the code does not try to update the column
        depth_cache_sql = options[:depth_cache_column]&.to_s || 'ancestry_depth'
      elsif options[:cache_depth]
        # Create accessor for column name and set to option or default
        cattr_accessor :depth_cache_column
        self.depth_cache_column =
          if options[:cache_depth] == true
            options[:depth_cache_column]&.to_s || 'ancestry_depth'
          else
            options[:cache_depth].to_s
          end
        if options[:depth_cache_column]
          ActiveSupport::Deprecation.warn("has_ancestry :depth_cache_column is deprecated. Use :cache_depth instead.")
        end

        # Cache depth in depth cache column before save
        before_validation :cache_depth
        before_save :cache_depth

        # Validate depth column
        validates_numericality_of depth_cache_column, :greater_than_or_equal_to => 0, :only_integer => true, :allow_nil => false

        depth_cache_sql = depth_cache_column
      else
        # this is not efficient, but it works
        depth_cache_sql = ancestry_depth_sql
      end

      scope :before_depth, lambda { |depth| where("#{depth_cache_sql} < ?", depth) }
      scope :to_depth,     lambda { |depth| where("#{depth_cache_sql} <= ?", depth) }
      scope :at_depth,     lambda { |depth| where("#{depth_cache_sql} = ?", depth) }
      scope :from_depth,   lambda { |depth| where("#{depth_cache_sql} >= ?", depth) }
      scope :after_depth,  lambda { |depth| where("#{depth_cache_sql} > ?", depth) }

      # Create counter cache column accessor and set to option or default
      if options[:counter_cache]
        cattr_accessor :counter_cache_column
        self.counter_cache_column = options[:counter_cache] == true ? 'children_count' : options[:counter_cache].to_s

        after_create :increase_parent_counter_cache, if: :has_parent?
        after_destroy :decrease_parent_counter_cache, if: :has_parent?
        after_update :update_parent_counter_cache
      end

      if options[:touch]
        after_touch :touch_ancestors_callback
        after_destroy :touch_ancestors_callback
        after_save :touch_ancestors_callback, if: :saved_changes?
      end
    end

    def acts_as_tree(*args)
      return super if defined?(super)

      has_ancestry(*args)
    end

    def self.ancestry_format_module(ancestry_format)
      ancestry_format ||= Ancestry.default_ancestry_format
      if ancestry_format == :materialized_path2
        Ancestry::MaterializedPath2
      else
        Ancestry::MaterializedPath
      end
    end
  end
end

require 'active_support'
ActiveSupport.on_load :active_record do
  extend Ancestry::HasAncestry
end
