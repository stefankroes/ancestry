require_relative '../environment'

class ClassMethodsTest < ActiveSupport::TestCase
  def test_sql_concat
    AncestryTestDatabase.with_model do |model|
      result = model.send(:sql_concat, 'table_name.id', "'/'")

      case ActiveRecord::Base.connection.adapter_name.downcase.to_sym
      when :sqlite
        assert_equal result, "table_name.id || '/'"
      when :mysql
        assert_equal result, "CONCAT(table_name.id, '/')"
      when :postgresql
        assert_equal result, "CONCAT(table_name.id, '/')"
      end
    end
  end

  def text_sql_cast_as_text
    AncestryTestDatabase.with_model do |model|
      result = model.send(:sql_cast_as_text, 'table_name.id')

      case ActiveRecord::Base.connection.adapter_name.downcase.to_sym
      when :sqlite
        assert_equal result, 'CAST(table_name.id AS TEXT)'
      when :mysql
        assert_equal result, 'CAST(table_name.id AS CHAR)'
      when :postgresql
        assert_equal result, 'CAST(table_name.id AS TEXT)'
      end
    end
  end
end
