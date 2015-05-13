require_relative '../environment'

class ArrangementTest < ActiveSupport::TestCase
  def test_arrangement
    AncestryTestDatabase.with_model :depth => 3, :width => 3 do |model, roots|
      id_sorter = Proc.new do |a, b|; a.id <=> b.id; end
      arranged_nodes = model.arrange
      assert_equal 3, arranged_nodes.size
      arranged_nodes.each do |node, children|
        assert_equal node.children.sort(&id_sorter), children.keys.sort(&id_sorter)
        children.each do |node, children|
          assert_equal node.children.sort(&id_sorter), children.keys.sort(&id_sorter)
          children.each do |node, children|
            assert_equal 0, children.size
          end
        end
      end
    end
  end

  def test_arrange_serializable
    AncestryTestDatabase.with_model :depth => 2, :width => 2 do |model, roots|
      result = [{"ancestry"=>nil,
          "id"=>4,
          "children"=>
           [{"ancestry"=>"4", "id"=>6, "children"=>[]},
            {"ancestry"=>"4", "id"=>5, "children"=>[]}]},
         {"ancestry"=>nil,
          "id"=>1,
          "children"=>
           [{"ancestry"=>"1", "id"=>3, "children"=>[]},
            {"ancestry"=>"1", "id"=>2, "children"=>[]}]}]

      assert_equal model.arrange_serializable(order: "id desc"), result
    end
  end

  def test_arrange_serializable_with_block
    AncestryTestDatabase.with_model :depth => 2, :width => 2 do |model, roots|
      expected_result = [{
          "id"=>4,
          "childs"=>
           [{"id"=>6},
            {"id"=>5}]},
         {
          "id"=>1,
          "childs"=>
           [{"id"=>3},
            {"id"=>2}]}]
      result = model.arrange_serializable(order: "id desc") do |parent, children|
        out = {}
        out["id"] = parent.id
        out["childs"] = children if children.count > 1
        out
      end
      assert_equal result, expected_result
    end
  end

  def test_arrange_order_option
    AncestryTestDatabase.with_model :width => 3, :depth => 3 do |model, roots|
      descending_nodes_lvl0 = model.arrange :order => 'id desc'
      ascending_nodes_lvl0 = model.arrange :order => 'id asc'

      descending_nodes_lvl0.keys.zip(ascending_nodes_lvl0.keys.reverse).each do |descending_node, ascending_node|
        assert_equal descending_node, ascending_node
        descending_nodes_lvl1 = descending_nodes_lvl0[descending_node]
        ascending_nodes_lvl1 = ascending_nodes_lvl0[ascending_node]
        descending_nodes_lvl1.keys.zip(ascending_nodes_lvl1.keys.reverse).each do |descending_node, ascending_node|
          assert_equal descending_node, ascending_node
          descending_nodes_lvl2 = descending_nodes_lvl1[descending_node]
          ascending_nodes_lvl2 = ascending_nodes_lvl1[ascending_node]
          descending_nodes_lvl2.keys.zip(ascending_nodes_lvl2.keys.reverse).each do |descending_node, ascending_node|
            assert_equal descending_node, ascending_node
            descending_nodes_lvl3 = descending_nodes_lvl2[descending_node]
            ascending_nodes_lvl3 = ascending_nodes_lvl2[ascending_node]
            descending_nodes_lvl3.keys.zip(ascending_nodes_lvl3.keys.reverse).each do |descending_node, ascending_node|
              assert_equal descending_node, ascending_node
            end
          end
        end
      end
    end
  end

  def test_arrangement_nesting
    AncestryTestDatabase.with_model :extra_columns => {:name => :string} do |model|

      # Rails < 3.1 doesn't support lambda default_scopes (only hashes)
      # But Rails >= 4 logs deprecation warnings for hash default_scopes
      if ActiveRecord::VERSION::STRING < "3.1"
        model.send :default_scope, model.order('name')
      else
        model.send :default_scope, lambda { model.order('name') }
      end

      model.create!(:name => 'Linux').children.create! :name => 'Debian'

      assert_equal 1, model.arrange.count
    end
  end
end
