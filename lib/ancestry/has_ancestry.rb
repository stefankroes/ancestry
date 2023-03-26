module Ancestry
  module HasAncestry
    def has_ancestry options = {}
      # Check options
      raise Ancestry::AncestryException.new(I18n.t("ancestry.option_must_be_hash")) unless options.is_a? Hash
      options.each do |key, value|
        unless [:ancestry_column, :orphan_strategy, :cache_depth, :depth_cache_column, :touch, :counter_cache, :primary_key_format, :update_strategy, :ancestry_format].include? key
          raise Ancestry::AncestryException.new(I18n.t("ancestry.unknown_option", key: key.inspect, value: value.inspect))
        end
      end

      if options[:ancestry_format].present? && ![:materialized_path, :materialized_path2].include?( options[:ancestry_format] )
        raise Ancestry::AncestryException.new(I18n.t("ancestry.unknown_format", value: options[:ancestry_format]))
      end

      orphan_strategy = options[:orphan_strategy] || :destroy

      # Create ancestry column accessor and set to option or default
      self.class_variable_set('@@ancestry_column', options[:ancestry_column] || :ancestry)
      cattr_reader :ancestry_column, instance_reader: false

      primary_key_format = options[:primary_key_format].presence || Ancestry.default_primary_key_format

      self.class_variable_set('@@ancestry_delimiter', '/')
      cattr_reader :ancestry_delimiter, instance_reader: false

      # Save self as base class (for STI)
      self.class_variable_set('@@ancestry_base_class', self)
      cattr_reader :ancestry_base_class, instance_reader: false

      # Touch ancestors after updating
      # days are limited. need to handle touch in pg case
      cattr_accessor :touch_ancestors
      self.touch_ancestors = options[:touch] || false

      # Include instance methods
      include Ancestry::InstanceMethods

      # Include dynamic class methods
      extend Ancestry::ClassMethods

      cattr_accessor :ancestry_format
      self.ancestry_format = options[:ancestry_format] || Ancestry.default_ancestry_format

      if ancestry_format == :materialized_path2
        extend Ancestry::MaterializedPath2
      else
        extend Ancestry::MaterializedPath
      end

      attribute self.ancestry_column, default: self.ancestry_root

      validates self.ancestry_column, ancestry_validation_options(primary_key_format)

      update_strategy = options[:update_strategy] || Ancestry.default_update_strategy
      include Ancestry::MaterializedPathPg if update_strategy == :sql

      # Validate that the ancestor ids don't include own id
      validate :ancestry_exclude_self

      # Update descendants with new ancestry after update
      after_update :update_descendants_with_new_ancestry, if: :ancestry_changed?

      # Apply orphan strategy before destroy
      case orphan_strategy
      when :rootify
        alias_method :apply_orphan_strategy, :apply_orphan_strategy_rootify
      when :destroy
        alias_method :apply_orphan_strategy, :apply_orphan_strategy_destroy
      when :adopt
        alias_method :apply_orphan_strategy, :apply_orphan_strategy_adopt
      when :restrict
        alias_method :apply_orphan_strategy, :apply_orphan_strategy_restrict
      else
        raise Ancestry::AncestryException.new(I18n.t("ancestry.invalid_orphan_strategy"))
      end
      before_destroy :apply_orphan_strategy

      # Create ancestry column accessor and set to option or default
      if options[:cache_depth]
        # Create accessor for column name and set to option or default
        self.cattr_accessor :depth_cache_column
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

        scope :before_depth, lambda { |depth| where("#{depth_cache_column} < ?", depth) }
        scope :to_depth,     lambda { |depth| where("#{depth_cache_column} <= ?", depth) }
        scope :at_depth,     lambda { |depth| where("#{depth_cache_column} = ?", depth) }
        scope :from_depth,   lambda { |depth| where("#{depth_cache_column} >= ?", depth) }
        scope :after_depth,  lambda { |depth| where("#{depth_cache_column} > ?", depth) }
      else
        # this is not efficient, but it works
        scope :before_depth, lambda { |depth| where("#{ancestry_depth_sql} < ?", depth) }
        scope :to_depth,     lambda { |depth| where("#{ancestry_depth_sql} <= ?", depth) }
        scope :at_depth,     lambda { |depth| where("#{ancestry_depth_sql} = ?", depth) }
        scope :from_depth,   lambda { |depth| where("#{ancestry_depth_sql} >= ?", depth) }
        scope :after_depth,  lambda { |depth| where("#{ancestry_depth_sql} > ?", depth) }
      end

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
  end
end

require 'active_support'
ActiveSupport.on_load :active_record do
  extend Ancestry::HasAncestry
end
