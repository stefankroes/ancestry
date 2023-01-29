module Ancestry
  module HasAncestry
    def has_ancestry options = {}

      if base_class != self
        ActiveSupport::Deprecation.warn("Please move has_ancestry to the root of the STI inheritance tree.")
      end

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

      self.class_variable_set('@@ancestry_options', {
        primary_key_format: options[:primary_key_format].presence || Ancestry.default_primary_key_format,
        touch: options[:touch] || false,
        ancestry_format: options[:ancestry_format] || Ancestry.default_ancestry_format,
        cache_depth: options[:cache_depth] || false,
        depth_cache_column: options[:depth_cache_column] || :ancestry_depth,
        counter_cache: options[:counter_cache],
        counter_cache_column: options[:counter_cache] == true ? 'children_count' : options[:counter_cache].to_s,
        update_strategy: options[:update_strategy] || Ancestry.default_update_strategy,
        orphan_strategy: options[:orphan_strategy] || :destroy,
      }.freeze)
      cattr_reader :ancestry_options, instance_reader: false

      self.class_variable_set('@@ancestry_delimiter', '/')
      cattr_reader :ancestry_delimiter, instance_reader: false

      # Save self as base class (for STI)
      self.class_variable_set('@@ancestry_base_class', self)
      cattr_reader :ancestry_base_class, instance_reader: false

      # Include instance methods
      include Ancestry::InstanceMethods

      # Include dynamic class methods
      extend Ancestry::ClassMethods

      if ancestry_options[:ancestry_format] == :materialized_path2
        extend Ancestry::MaterializedPath2
      else
        extend Ancestry::MaterializedPath
      end

      attribute self.ancestry_column, default: self.ancestry_root
      validates self.ancestry_column, ancestry_validation_options

      if ancestry_options[:update_strategy] == :sql
        include Ancestry::MaterializedPathPg
      end

      # Validate that the ancestor ids don't include own id
      validate :ancestry_exclude_self

      # Update descendants with new ancestry after update
      after_update :update_descendants_with_new_ancestry

      # Apply orphan strategy before destroy
      case orphan_strategy
      when :rootify  then before_destroy :apply_orphan_strategy_rootify
      when :destroy  then before_destroy :apply_orphan_strategy_destroy
      when :adopt    then before_destroy :apply_orphan_strategy_adopt
      when :restrict then before_destroy :apply_orphan_strategy_restrict
      else raise Ancestry::AncestryException.new(I18n.t("ancestry.invalid_orphan_strategy"))
      end

      # Create ancestry column accessor and set to option or default
      if ancestry_options[:cache_depth]
        # Cache depth in depth cache column before save
        before_validation :cache_depth
        before_save :cache_depth

        # Validate depth column
        validates_numericality_of ancestry_options[:depth_cache_column], greater_than_or_equal_to: 0, only_integer: true, allow_nil: false
      end

      # Create counter cache column accessor and set to option or default
      if ancestry_options[:counter_cache]
        after_create :increase_parent_counter_cache, if: :has_parent?
        after_destroy :decrease_parent_counter_cache, if: :has_parent?
        after_update :update_parent_counter_cache
      end

      # Create named scopes for depth
      {:before_depth => '<', :to_depth => '<=', :at_depth => '=', :from_depth => '>=', :after_depth => '>'}.each do |scope_name, operator|
        scope scope_name, lambda { |depth|
          raise Ancestry::AncestryException.new(I18n.t("ancestry.named_scope_depth_cache",
                                                       :scope_name => scope_name
                                                       )) unless ancestry_options[:cache_depth]
          where("#{ancestry_options[:depth_cache_column]} #{operator} ?", depth)
        }
      end

      after_touch :touch_ancestors_callback
      after_destroy :touch_ancestors_callback
      after_save :touch_ancestors_callback, if: :saved_changes?
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
