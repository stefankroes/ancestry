# frozen_string_literal: true

module Ancestry
  module HasAncestry
    def has_ancestry(options = {})
      # Check options
      unless options.is_a? Hash
        raise Ancestry::AncestryException, I18n.t("ancestry.option_must_be_hash")
      end

      extra_keys = options.keys - [:ancestry_column, :orphan_strategy, :cache_depth, :depth_cache_column, :touch, :counter_cache, :primary_key_format, :update_strategy, :ancestry_format, :format, :parent, :root, :associations]
      if (key = extra_keys.first)
        raise Ancestry::AncestryException, I18n.t("ancestry.unknown_option", key: key.inspect, value: options[key].inspect)
      end

      ancestry_format = options[:ancestry_format] || options[:format] || Ancestry.default_ancestry_format
      if ![:materialized_path, :materialized_path2, :materialized_path3, :ltree, :array].include?(ancestry_format)
        raise Ancestry::AncestryException, I18n.t("ancestry.unknown_format", value: ancestry_format)
      end

      orphan_strategy = options[:orphan_strategy] || :destroy

      column = options[:ancestry_column] || :ancestry

      primary_key_format, integer_pk = resolve_primary_key_format(options[:primary_key_format].presence || Ancestry.default_primary_key_format)

      # Save self as base class (for STI)
      class_variable_set('@@ancestry_base_class', self)
      cattr_reader :ancestry_base_class, instance_reader: false

      # Include instance methods
      include Ancestry::InstanceMethods

      # Include dynamic class methods
      extend Ancestry::ClassMethods

      format_module = Ancestry::HasAncestry.ancestry_format_module(ancestry_format)
      root = format_module.root

      # Resolve depth cache column name (or nil if virtual/absent)
      if options[:cache_depth] == :virtual
        depth_cache_column = nil
        depth_cache_sql = options[:depth_cache_column]&.to_s || 'ancestry_depth'
      elsif options[:cache_depth]
        if options[:depth_cache_column]
          Ancestry.deprecator.warn("has_ancestry :depth_cache_column is deprecated. Use :cache_depth instead.")
        end
        depth_cache_column =
          if options[:cache_depth] == true
            options[:depth_cache_column]&.to_s || 'ancestry_depth'
          else
            options[:cache_depth].to_s
          end
        depth_cache_sql = depth_cache_column
      else
        depth_cache_column = nil
        depth_cache_sql = nil
      end

      # Resolve parent cache column name (or nil if virtual/absent)
      # Virtual columns have a DB column (for associations/reads) but aren't writable by callbacks
      if options[:parent] == :virtual
        parent_cache_column = nil
        parent_column = 'parent_id'
      elsif options[:parent]
        parent_cache_column = options[:parent] == true ? 'parent_id' : options[:parent].to_s
        parent_column = parent_cache_column
      else
        parent_cache_column = nil
        parent_column = nil
      end

      # Resolve root cache column name (or nil if virtual/absent)
      # Virtual columns have a DB column (for associations/reads) but aren't writable by callbacks
      if options[:root] == :virtual
        root_cache_column = nil
        root_column = 'root_id'
      elsif options[:root]
        root_cache_column = options[:root] == true ? 'root_id' : options[:root].to_s
        root_column = root_cache_column
      else
        root_cache_column = nil
        root_column = nil
      end

      # Resolve counter cache column name (or nil)
      counter_cache_column = if options[:counter_cache]
        options[:counter_cache] == true ? 'children_count' : options[:counter_cache].to_s
      end

      # Define associations before including the builder module.
      # The builder module is higher in MRO and overrides the association methods,
      # but the association reflections remain available for includes/preload/inverse_of.
      # super from builder methods reaches the association's generated methods.
      define_associations = options.fetch(:associations, true) != false

      parent_association = define_associations && parent_column
      root_association = define_associations && root_column

      if parent_association
        belongs_to :parent, class_name: self.name, foreign_key: parent_column,
                   optional: true, inverse_of: :children
        has_many :children, class_name: self.name, foreign_key: parent_column,
                 inverse_of: :parent
      end

      if root_association
        belongs_to :root, class_name: self.name, foreign_key: root_column,
                   optional: true
      end

      # Include generated module with baked-in column/format
      # This extends ClassMethods (scopes, helpers) and includes instance methods
      generated_mod = Ancestry::InstanceMethodsBuilder.build(
        format_module, column, root,
        integer_pk: integer_pk,
        depth_cache_column: depth_cache_column,
        counter_cache_column: counter_cache_column,
        parent_cache_column: parent_cache_column,
        root_cache_column: root_cache_column,
        parent_association: parent_association,
        root_association: root_association
      )
      include generated_mod

      attribute column, default: format_module.root

      if (vopts = ancestry_validation_options(primary_key_format))
        validates column, vopts
      end

      update_strategy = options[:update_strategy] || Ancestry.default_update_strategy

      # Validate that the ancestor ids don't include own id
      validate :ancestry_exclude_self

      # Validate descendants' depths don't exceed max depth when moving them
      validate :ancestry_depth_of_descendants, if: :ancestry_changed?

      # Update descendants with new ancestry after update
      if update_strategy == :sql
        after_update :update_descendants_with_new_ancestry_sql, if: :ancestry_changed?
      else
        after_update :update_descendants_with_new_ancestry, if: :ancestry_changed?
      end

      # Apply orphan strategy before destroy
      orphan_strategy_helper = "apply_orphan_strategy_#{orphan_strategy}"
      if method_defined?(orphan_strategy_helper)
        alias_method :apply_orphan_strategy, orphan_strategy_helper
        before_destroy :apply_orphan_strategy
      elsif orphan_strategy.to_s != "none"
        raise Ancestry::AncestryException, I18n.t("ancestry.invalid_orphan_strategy")
      end

      # Depth cache validation
      if depth_cache_column
        validates_numericality_of depth_cache_column, :greater_than_or_equal_to => 0, :only_integer => true, :allow_nil => false
      end

      # Cache column callbacks
      if depth_cache_column || parent_cache_column || root_cache_column
        before_validation :cache_ancestry_columns
        before_save :cache_ancestry_columns
      end

      # Root id requires the record's id, which isn't available until after insert
      if root_cache_column
        after_create :cache_ancestry_columns_after_create
      end

      # Depth scopes
      depth_cache_sql ||= ancestry_depth_sql
      scope :before_depth, lambda { |depth| where("#{depth_cache_sql} < ?", depth) }
      scope :to_depth,     lambda { |depth| where("#{depth_cache_sql} <= ?", depth) }
      scope :at_depth,     lambda { |depth| where("#{depth_cache_sql} = ?", depth) }
      scope :from_depth,   lambda { |depth| where("#{depth_cache_sql} >= ?", depth) }
      scope :after_depth,  lambda { |depth| where("#{depth_cache_sql} > ?", depth) }

      # Counter cache callbacks
      if counter_cache_column
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

    PRIMARY_KEY_FORMATS = {
      integer: ['[0-9]+', true],
      uuid:    ['[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}', false],
      string:  ['[a-zA-Z0-9_-]+', false],
    }.freeze

    # Resolve primary_key_format to [regex_string, integer_pk]
    def resolve_primary_key_format(value)
      return PRIMARY_KEY_FORMATS[value] if PRIMARY_KEY_FORMATS.key?(value)

      # Infer from custom regex: if it can match a letter, it's not integer-only
      [value, !Regexp.new(value).match?("a")]
    end

    def self.ancestry_format_module(ancestry_format)
      ancestry_format ||= Ancestry.default_ancestry_format
      case ancestry_format
      when :materialized_path2
        Ancestry::MaterializedPath2
      when :materialized_path3
        Ancestry::MaterializedPath3
      when :ltree
        Ancestry::Ltree
      when :array
        Ancestry::MaterializedPathArray
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
