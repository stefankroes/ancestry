# frozen_string_literal: true

module Ancestry
  module Migration
    # Migration helper for creating ancestry columns, indexes, and cache columns.
    #
    # @example Basic usage
    #   create_table :nodes do |t|
    #     t.ancestry
    #   end
    #
    # @example With format and cache columns
    #   create_table :nodes do |t|
    #     t.ancestry format: :materialized_path2, cache_depth: true, parent: true, counter_cache: true
    #   end
    #
    # @param column [Symbol] ancestry column name (default: :ancestry)
    # @param format [Symbol] :materialized_path, :materialized_path2, :materialized_path3, :ltree, :array
    # @param collation [String, nil, false] collation for string ancestry column (default: auto-detect binary collation for LIKE index usage; false to disable)
    # @param cache_depth [Boolean, :virtual] add ancestry_depth integer column
    # @param parent [Boolean, :virtual] add parent_id integer column
    # @param root [Boolean, :virtual] add root_id integer column
    # @param counter_cache [Boolean] add children_count integer column
    def ancestry(column = :ancestry, format: nil, collation: nil, cache_depth: false, parent: false, root: false, counter_cache: false)
      format ||= Ancestry.default_ancestry_format
      format_module = Ancestry::HasAncestry.ancestry_format_module(format)
      table_name = self.name # table name from TableDefinition

      # Add the ancestry column with appropriate type and options
      case format
      when :ltree
        self.column column, :ltree, default: '', null: false
      when :array
        integer column, array: true, default: [], null: false
      else
        not_null = format != :materialized_path
        opts = { null: !not_null }
        unless collation == false
          col = collation.is_a?(String) ? collation : ascii_collation
          opts[:collation] = col if col
        end
        string column, **opts
      end

      # Add indexes
      case format
      when :ltree
        index column, using: :gist
      when :array
        index column, name: "index_#{table_name}_on_#{column}_btree"
        index column, using: :gin, name: "index_#{table_name}_on_#{column}_gin"
      else
        index column
      end

      # Add cache columns
      add_ancestry_cache_column(cache_depth, :ancestry_depth, column, default: 0, null: false) do |col|
        format_module.construct_depth_sql(nil, col, format_module.delimiter)
      end

      add_ancestry_cache_column(parent, :parent_id, column, default: nil, null: true) do |col|
        format_module.construct_parent_id_sql(nil, col, format_module.delimiter, detect_adapter)
      end

      add_ancestry_cache_column(root, :root_id, column, default: nil, null: true) do |col|
        format_module.construct_root_id_sql(nil, col, format_module.delimiter, 'id', detect_adapter)
      end

      # Counter cache
      if counter_cache
        counter_col = counter_cache == true ? :children_count : counter_cache
        integer counter_col, default: 0, null: false
      end
    end

    private

    def add_ancestry_cache_column(value, default_column, ancestry_column, default: 0, null: false)
      case value
      when true
        integer default_column, default: default, null: null
        index default_column
      when :virtual
        sql = yield(ancestry_column)
        virtual default_column, type: :integer, as: sql, stored: true
        index default_column
      when false, nil then nil # no column
      else
        integer value, default: default, null: null
        index value
      end
    end

    def detect_adapter
      if defined?(ActiveRecord::Base) && ActiveRecord::Base.connected?
        ActiveRecord::Base.connection.adapter_name.downcase
      else
        "sqlite3"
      end
    end

    # Binary collation for LIKE prefix queries to use btree indexes.
    # Without this, postgres/mysql use locale-aware ordering which prevents index usage for LIKE.
    def ascii_collation
      case detect_adapter
      when "postgresql" then "C"
      when "mysql2", "trilogy", "mysql" then "utf8mb4_bin"
      end
    end
  end
end

ActiveSupport.on_load :active_record do
  ActiveRecord::ConnectionAdapters::TableDefinition.include(Ancestry::Migration)
end
