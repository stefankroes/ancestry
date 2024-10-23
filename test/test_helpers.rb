# frozen_string_literal: true

module TestHelpers
  def assert_ancestry(node, value, child: :skip, db: :value)
    column_name = node.class.ancestry_column
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
