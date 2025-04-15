# frozen_string_literal: true

module Ancestry
  # Adds eager loading capabilities to Ancestry methods
  module EagerLoading
    # Eager loads a specific ancestry association
    def with_ancestry(association, scope = nil)
      case association.to_sym
      when :ancestors
        with_ancestors(scope)
      when :descendants
        with_descendants(scope)
      when :children
        with_children(scope)
      when :parent
        with_parent(scope)
      when :siblings
        with_siblings(scope)
      when :indirects
        with_indirects(scope)
      when :subtree
        with_subtree(scope)
      else
        raise Ancestry::AncestryException, I18n.t("ancestry.unknown_association", association: association)
      end
    end

    # Eager loads complete tree in a single query and returns an ActiveRecord::Relation
    def with_tree(scope = nil)
      relation = scope || all
      model = relation.klass
      
      # Execute the query once to get all records
      records = relation.to_a
      return relation if records.empty?
      
      # Index all records by their primary key for fast lookup
      preloaded_records = {}
      records.each do |record|
        preloaded_records[record.id.to_s] = record
      end
      
      # Set up parent-child relationships
      records.each do |record|
        if record.has_parent? && (parent = preloaded_records[record.parent_id.to_s])
          # Set up bidirectional relationships without additional queries
          record.instance_variable_set(:@_eager_loaded_parent, parent)
          
          # Initialize children array for parent if not exists
          parent_children = parent.instance_variable_get(:@_eager_loaded_children) || []
          parent_children << record
          parent.instance_variable_set(:@_eager_loaded_children, parent_children)
        else
          # Ensure root nodes have an empty children array
          record.instance_variable_set(:@_eager_loaded_children, []) unless record.instance_variable_defined?(:@_eager_loaded_children)
        end
      end
      
      # Store the preloaded records in the relation
      relation.instance_variable_set(:@ancestry_preloaded_records, records)
      
      # Return the relation for chainability
      relation
    end

    # Eager loads ancestors
    def with_ancestors(scope = nil)
      relation = scope || all
      model = relation.klass
      
      # Execute the query once to get all records
      records = relation.to_a
      return relation if records.empty?
      
      # Collect all ancestor_ids
      ancestor_ids = records.flat_map(&:ancestor_ids).uniq
      
      # Return early if no ancestors
      return relation if ancestor_ids.empty?
      
      # Load all ancestors in a single query
      ancestors = unscoped_where { |scope| scope.where(primary_key => ancestor_ids) }.to_a
      
      # Create lookup hash
      ancestors_by_id = {}
      ancestors.each { |ancestor| ancestors_by_id[ancestor.id.to_s] = ancestor }
      
      # Set up ancestors for each record
      records.each do |record|
        loaded_ancestors = record.ancestor_ids.map { |id| ancestors_by_id[id.to_s] }.compact
        record.instance_variable_set(:@_eager_loaded_ancestors, loaded_ancestors)
        
        # For better navigation, also set up parent reference
        if record.has_parent? && (parent = ancestors_by_id[record.parent_id.to_s])
          record.instance_variable_set(:@_eager_loaded_parent, parent)
        end
      end
      
      # Store the preloaded records in the relation
      relation.instance_variable_set(:@ancestry_preloaded_records, records)
      
      # Return the relation for chainability
      relation
    end

    # Eager loads descendants
    def with_descendants(scope = nil)
      relation = scope || all
      model = relation.klass
      
      # Execute the query once to get all records
      records = relation.to_a
      return relation if records.empty?
      
      # Get all records' child ancestries
      child_ancestries = records.map(&:child_ancestry)
      
      # Return early if there are no descendants
      return relation if child_ancestries.empty?
      
      # Load all descendants in a single query
      t = arel_table
      conditions = child_ancestries.map do |ancestry|
        t[ancestry_column].eq(ancestry).or(
          t[ancestry_column].matches("#{ancestry}#{ancestry_delimiter}%", nil, true)
        )
      end.inject(&:or)
      
      descendants = unscoped_where { |scope| scope.where(conditions) }.to_a
      
      # Group descendants by their ancestry path
      descendants_by_path = {}
      descendants.each do |descendant|
        parent_id = descendant.parent_id.to_s
        descendants_by_path[parent_id] ||= []
        descendants_by_path[parent_id] << descendant
      end
      
      # Attach immediate children to each record
      records.each do |record|
        record_descendants = descendants_by_path[record.id.to_s] || []
        record.instance_variable_set(:@_eager_loaded_children, record_descendants)
        
        # Recursively build the descendant tree
        build_descendant_tree(record, record_descendants, descendants_by_path)
      end
      
      # Store the preloaded records in the relation
      relation.instance_variable_set(:@ancestry_preloaded_records, records)
      
      # Return the relation for chainability
      relation
    end

    # Eager loads children
    def with_children(scope = nil)
      relation = scope || all
      model = relation.klass
      
      # Execute the query once to get all records
      records = relation.to_a
      return relation if records.empty?
      
      # Load all children in a single query
      child_conditions = records.map do |record|
        "#{ancestry_column} = '#{record.child_ancestry}'"
      end.join(' OR ')
      
      return relation if child_conditions.blank?
      
      children = unscoped_where { |scope| scope.where(child_conditions) }.to_a
      
      # Group children by parent_id
      children_by_parent = {}
      children.each do |child|
        parent_id = child.parent_id.to_s
        children_by_parent[parent_id] ||= []
        children_by_parent[parent_id] << child
      end
      
      # Attach children to parents and parents to children
      records.each do |record|
        record_children = children_by_parent[record.id.to_s] || []
        record.instance_variable_set(:@_eager_loaded_children, record_children)
        
        # Set up bidirectional relationships
        record_children.each do |child|
          child.instance_variable_set(:@_eager_loaded_parent, record)
        end
      end
      
      # Store the preloaded records in the relation
      relation.instance_variable_set(:@ancestry_preloaded_records, records)
      
      # Return the relation for chainability
      relation
    end

    # Eager loads parent
    def with_parent(scope = nil)
      relation = scope || all
      model = relation.klass
      
      # Execute the query once to get all records
      records = relation.to_a
      return relation if records.empty?
      
      # Get all parent IDs
      parent_ids = records.map(&:parent_id).compact.uniq
      
      # Return early if no parents
      return relation if parent_ids.empty?
      
      # Load all parents in a single query
      parents = unscoped_where { |scope| scope.where(primary_key => parent_ids) }.to_a
      
      # Create lookup hash
      parents_by_id = {}
      parents.each { |parent| parents_by_id[parent.id.to_s] = parent }
      
      # Set up parent for each record
      records.each do |record|
        if record.parent_id && (parent = parents_by_id[record.parent_id.to_s])
          record.instance_variable_set(:@_eager_loaded_parent, parent)
        end
      end
      
      # Store the preloaded records in the relation
      relation.instance_variable_set(:@ancestry_preloaded_records, records)
      
      # Return the relation for chainability
      relation
    end

    # Eager loads siblings
    def with_siblings(scope = nil)
      relation = scope || all
      model = relation.klass
      
      # Execute the query once to get all records
      records = relation.to_a
      return relation if records.empty?
      
      # Group records by ancestry
      records_by_ancestry = {}
      records.each do |record|
        ancestry = record[ancestry_column]
        records_by_ancestry[ancestry] ||= []
        records_by_ancestry[ancestry] << record
      end
      
      # For each unique ancestry value, load all siblings
      all_siblings = []
      records_by_ancestry.each do |ancestry, ancestry_records|
        # Skip records with no ancestry if they're already loaded
        next if ancestry.nil? && ancestry_records.length == records.select { |r| r[ancestry_column].nil? }.length
        
        # Load siblings
        siblings = unscoped_where { |scope| scope.where(ancestry_column => ancestry) }.to_a
        
        # Attach siblings to each record
        ancestry_records.each do |record|
          record_siblings = siblings.reject { |s| s.id == record.id }
          record.instance_variable_set(:@_eager_loaded_siblings, record_siblings)
        end
        
        all_siblings.concat(siblings)
      end
      
      # Store the preloaded records in the relation
      relation.instance_variable_set(:@ancestry_preloaded_records, records)
      
      # Return the relation for chainability
      relation
    end

    # Eager loads indirects (descendants that are not direct children)
    def with_indirects(scope = nil)
      relation = scope || all
      
      # Use with_descendants to get all descendants
      descendants_relation = with_descendants(relation)
      
      # Get the preloaded records
      if descendants_relation.instance_variable_defined?(:@ancestry_preloaded_records)
        records = descendants_relation.instance_variable_get(:@ancestry_preloaded_records)
        
        # For each record, set indirect descendants (all descendants except children)
        records.each do |record|
          children = record.instance_variable_get(:@_eager_loaded_children) || []
          descendants = collect_descendants(record)
          indirects = descendants - children
          record.instance_variable_set(:@_eager_loaded_indirects, indirects)
        end
      end
      
      # Return the relation for chainability
      descendants_relation
    end
    
    # Eager loads subtree (self + descendants)
    def with_subtree(scope = nil)
      relation = scope || all
      
      # Use with_descendants to get all descendants
      descendants_relation = with_descendants(relation)
      
      # Get the preloaded records
      if descendants_relation.instance_variable_defined?(:@ancestry_preloaded_records)
        records = descendants_relation.instance_variable_get(:@ancestry_preloaded_records)
        
        # For each record, set subtree (self + descendants)
        records.each do |record|
          descendants = collect_descendants(record)
          record.instance_variable_set(:@_eager_loaded_subtree, [record] + descendants)
        end
      end
      
      # Return the relation for chainability
      descendants_relation
    end

    private
    
    # Recursively build descendant tree
    def build_descendant_tree(record, children, descendants_by_path)
      children.each do |child|
        child_descendants = descendants_by_path[child.id.to_s] || []
        child.instance_variable_set(:@_eager_loaded_children, child_descendants)
        child.instance_variable_set(:@_eager_loaded_parent, record)
        
        # Recurse
        build_descendant_tree(child, child_descendants, descendants_by_path)
      end
    end
    
    # Collect all descendants for a record with cached descendants
    def collect_descendants(record, descendants = [])
      children = record.instance_variable_get(:@_eager_loaded_children) || []
      
      children.each do |child|
        descendants << child
        collect_descendants(child, descendants)
      end
      
      descendants
    end
  end
end
