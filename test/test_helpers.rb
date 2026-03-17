# frozen_string_literal: true

module TestHelpers
  IGNORED_SQL = /\A\s*(BEGIN|COMMIT|SAVEPOINT|RELEASE SAVEPOINT|ROLLBACK)/i

  # Assert the number of SQL queries executed in a block.
  # Filters out transaction management and schema queries.
  #
  #   assert_queries(2) { node.update!(parent: other) }
  #   assert_queries(2..3) { node.update!(parent: other) }
  #
  def assert_queries(expected, message = nil, &block)
    queries = []
    counter = ->(_name, _start, _finish, _id, payload) {
      return if payload[:name] == "SCHEMA" || payload[:cached]
      return if payload[:sql].match?(IGNORED_SQL)
      queries << payload[:sql]
    }
    result = ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    matched = expected === queries.size
    unless matched
      msg = message || "Expected #{expected} queries, got #{queries.size}"
      msg = "#{msg}\n#{queries.map.with_index { |q, i| "  #{i + 1}. #{q}" }.join("\n")}"
      flunk msg
    end
    result
  end

  def assert_ancestry(node, value, child: :skip, db: :value)
    column_name = AncestryTestDatabase.ancestry_column
    if value.nil?
      assert_nil node.send(column_name)
    else
      assert_equal value, node.send(column_name)
    end

    db = value if db == :value
    if db.nil?
      assert_nil node.send("#{column_name}_in_database")
    else
      assert_equal db, node.send("#{column_name}_in_database")
    end

    if child.nil?
      assert_nil node.child_ancestry
    elsif child != :skip
      assert_equal child, node.child_ancestry
    end
  end
end
