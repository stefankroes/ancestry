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
      PG.include?(normalize(adapter))
    end

    def mysql?(adapter = current)
      MYSQL.include?(normalize(adapter))
    end

    def sqlite?(adapter = current)
      SQLITE.include?(normalize(adapter))
    end

    def current
      ActiveRecord::Base.connection.adapter_name
    end

    private

    def normalize(adapter)
      adapter.to_s.downcase
    end
  end
end
