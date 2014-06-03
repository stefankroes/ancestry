require File.expand_path('../../environment', __FILE__)

class BuildAncestryTest < ActiveSupport::TestCase
  def test_build_ancestry_from_parent_ids
    AncestryTestDatabase.with_model :skip_ancestry => true, :extra_columns => {:parent_id => :integer} do |model|
      [model.create!].each do |parent|
        (Array.new(5) { model.create! :parent_id => parent.id }).each do |parent|
          (Array.new(5) { model.create! :parent_id => parent.id }).each do |parent|
            (Array.new(5) { model.create! :parent_id => parent.id })
          end
        end
      end

      # Assert all nodes where created
      assert_equal (0..3).map { |n| 5 ** n }.sum, model.count

      model.has_ancestry
      model.build_ancestry_from_parent_ids!

      # Assert ancestry integrity
      assert_nothing_raised do
        model.check_ancestry_integrity!
      end

      roots = model.roots.to_a
      # Assert single root node
      assert_equal 1, roots.size

      # Assert it has 5 children
      roots.each do |parent|
        assert_equal 5, parent.children.count
        parent.children.each do |parent|
          assert_equal 5, parent.children.count
          parent.children.each do |parent|
            assert_equal 5, parent.children.count
            parent.children.each do |parent|
              assert_equal 0, parent.children.count
            end
          end
        end
      end
    end
  end
end