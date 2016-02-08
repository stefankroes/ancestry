require_relative '../environment'

class HasAncestryTreeTest < ActiveSupport::TestCase
  def test_default_ancestry_column
    AncestryTestDatabase.with_model do |model|
      assert_equal :ancestry, model.ancestry_column
    end
  end

  def test_non_default_ancestry_column
    AncestryTestDatabase.with_model :ancestry_column => :alternative_ancestry do |model|
      assert_equal :alternative_ancestry, model.ancestry_column
    end
  end

  def test_setting_ancestry_column
    AncestryTestDatabase.with_model do |model|
      model.ancestry_column = :ancestors
      assert_equal :ancestors, model.ancestry_column
      model.ancestry_column = :ancestry
      assert_equal :ancestry, model.ancestry_column
    end
  end

  def test_default_ancestry_delimiter
    AncestryTestDatabase.with_model do |model|
      assert_equal "/", model.ancestry_delimiter
    end
  end

  def test_non_default_ancestry_delimiter
    AncestryTestDatabase.with_model :ancestry_delimiter => ',' do |model|
      assert_equal ',', model.ancestry_delimiter
    end
  end

  def test_setting_ancestry_delimiter
    AncestryTestDatabase.with_model do |model|
      model.ancestry_column = :ancestors
      assert_equal :ancestors, model.ancestry_column
      model.ancestry_column = :ancestry
      assert_equal :ancestry, model.ancestry_column
    end
  end

  def test_setting_invalid_ancestry_delimiter
    AncestryTestDatabase.with_model do |model|
      assert_raise Ancestry::AncestryException do
        model.ancestry_delimiter = '1'
      end
    end
  end

  def test_default_primary_key_format
    AncestryTestDatabase.with_model do |model|
      assert_equal "[0-9]+", model.primary_key_format
    end
  end

  def test_non_default_primary_key_format
    AncestryTestDatabase.with_model :primary_key_format => '[A-Z]+' do |model|
      assert_equal '[A-Z]+', model.primary_key_format
    end
  end

  def test_setting_invalid_ancestry_delimiter
    AncestryTestDatabase.with_model do |model|
      assert_raise Ancestry::AncestryException do
        model.ancestry_delimiter = '1'
      end
    end
  end

  def test_invalid_has_ancestry_options
    assert_raise Ancestry::AncestryException do
      Class.new(ActiveRecord::Base).has_ancestry :this_option_doesnt_exist => 42
    end
    assert_raise Ancestry::AncestryException do
      Class.new(ActiveRecord::Base).has_ancestry :not_a_hash
    end
  end

  def test_descendants_move_with_node
    AncestryTestDatabase.with_model :depth => 3, :width => 3 do |model, roots|
      root1, root2, root3 = roots.map(&:first)
      assert_no_difference 'root1.descendants.size' do
        assert_difference 'root2.descendants.size', root1.subtree.size do
          root1.parent = root2
          root1.save!
        end
      end
      assert_no_difference 'root2.descendants.size' do
        assert_difference 'root3.descendants.size', root2.subtree.size do
          root2.parent = root3
          root2.save!
        end
      end
      assert_no_difference 'root1.descendants.size' do
        assert_difference 'root2.descendants.size', -root1.subtree.size do
          assert_difference 'root3.descendants.size', -root1.subtree.size do
            root1.parent = nil
            root1.save!
          end
        end
      end
    end
  end

  def test_set_parent_with_non_default_ancestry_column
    AncestryTestDatabase.with_model :depth => 3, :width => 3, :ancestry_column => :alternative_ancestry do |model, roots|
      root1, root2, _root3 = roots.map(&:first)
      assert_no_difference 'root1.descendants.size' do
        assert_difference 'root2.descendants.size', root1.subtree.size do
          root1.parent = root2
          root1.save!
        end
      end
    end
  end

  def test_setup_test_nodes
    AncestryTestDatabase.with_model :depth => 3, :width => 3 do |model, roots|
      assert_equal Array, roots.class
      assert_equal 3, roots.length
      roots.each do |node1, children1|
        assert_equal model, node1.class
        assert_equal Array, children1.class
        assert_equal 3, children1.length
        children1.each do |node2, children2|
          assert_equal model, node2.class
          assert_equal Array, children2.class
          assert_equal 3, children2.length
          children2.each do |node3, children3|
            assert_equal model, node3.class
            assert_equal Array, children3.class
            assert_equal 0, children3.length
          end
        end
      end
    end
  end
end
