# frozen_string_literal: true

module Ancestry
  # Adapter detection helpers — small wrappers around the connection's
  # adapter_name. Centralizes the magic strings so format modules and
  # other call sites stop duplicating the matcher arrays.
  module Adapter
    extend self

    PG     = %w(pg postgresql postgis).freeze
    MYSQL  = %w(mysql mysql2 trilogy).freeze
    SQLITE = %w(sqlite sqlite3).freeze

    def pg?(adapter = current)
      PG.include?(adapter.to_s.downcase)
    end

    def mysql?(adapter = current)
      MYSQL.include?(adapter.to_s.downcase)
    end

    def sqlite?(adapter = current)
      SQLITE.include?(adapter.to_s.downcase)
    end

    def current
      ActiveRecord::Base.connection.adapter_name
    end

    # Cross-DB string concatenation. SQLite uses ||; PG/MySQL use CONCAT().
    # Returns a SQL fragment as a String — not an Arel node.
    def concat(adapter, *args)
      sqlite?(adapter) ? args.join('||') : "CONCAT(#{args.join(', ')})"
    end
  end
end
