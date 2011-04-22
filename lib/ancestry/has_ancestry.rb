require 'ancestry/class_methods'
require 'ancestry/instance_methods'
require 'ancestry/exceptions'

class << ActiveRecord::Base
  def has_ancestry options = {}
    # Check options
    raise Ancestry::AncestryException.new("Options for has_ancestry must be in a hash.") unless options.is_a? Hash
    options.each do |key, value|
      unless [:ancestry_column, :orphan_strategy, :cache_depth, :depth_cache_column, :primary_key_format].include? key
        raise Ancestry::AncestryException.new("Unknown option for has_ancestry: #{key.inspect} => #{value.inspect}.")
      end
    end
    
    # Include instance methods
    include Ancestry::InstanceMethods

    # Include dynamic class methods
    extend Ancestry::ClassMethods

    # Create ancestry column accessor and set to option or default
    cattr_accessor :ancestry_column
    self.ancestry_column = options[:ancestry_column] || :ancestry

    # Create orphan strategy accessor and set to option or default (writer comes from DynamicClassMethods)
    cattr_reader :orphan_strategy
    self.orphan_strategy = options[:orphan_strategy] || :destroy

    # Save self as base class (for STI)
    cattr_accessor :base_class
    self.base_class = self
    
    # Validate format of ancestry column value
    primary_key_format = options[:primary_key_format] || /[0-9]+/
    validates_format_of ancestry_column, :with => /\A#{primary_key_format.source}(\/#{primary_key_format.source})*\Z/, :allow_nil => true

    # Validate that the ancestor ids don't include own id
    validate :ancestry_exclude_self
    
    # Save ActiveRecord version
    self.cattr_accessor :rails_3
    self.rails_3 = defined?(ActiveRecord::VERSION) && ActiveRecord::VERSION::MAJOR >= 3
    
    # Workaround to support Rails 2
    scope_method = if rails_3 then :scope else :named_scope end

    # Named scopes
    send scope_method, :roots, :conditions => {ancestry_column => nil}
    send scope_method, :ancestors_of, lambda { |object| {:conditions => to_node(object).ancestor_conditions} }
    send scope_method, :children_of, lambda { |object| {:conditions => to_node(object).child_conditions} }
    send scope_method, :descendants_of, lambda { |object| {:conditions => to_node(object).descendant_conditions} }
    send scope_method, :subtree_of, lambda { |object| {:conditions => to_node(object).subtree_conditions} }
    send scope_method, :siblings_of, lambda { |object| {:conditions => to_node(object).sibling_conditions} }
    send scope_method, :ordered_by_ancestry, :order => "(case when #{table_name}.#{ancestry_column} is null then 0 else 1 end), #{table_name}.#{ancestry_column}"
    send scope_method, :ordered_by_ancestry_and, lambda { |order| {:order => "(case when #{table_name}.#{ancestry_column} is null then 0 else 1 end), #{table_name}.#{ancestry_column}, #{order}"} }
    
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

      # Validate depth column
      validates_numericality_of depth_cache_column, :greater_than_or_equal_to => 0, :only_integer => true, :allow_nil => false
    end
    
    # Create named scopes for depth
    {:before_depth => '<', :to_depth => '<=', :at_depth => '=', :from_depth => '>=', :after_depth => '>'}.each do |scope_name, operator|
      send scope_method, scope_name, lambda { |depth|
        raise Ancestry::AncestryException.new("Named scope '#{scope_name}' is only available when depth caching is enabled.") unless options[:cache_depth]
        {:conditions => ["#{depth_cache_column} #{operator} ?", depth]}
      }
    end
  end
  
  # Alias has_ancestry with acts_as_tree, if it's available.
  if !defined?(ActsAsTree) 
    alias_method :acts_as_tree, :has_ancestry
  end
end
