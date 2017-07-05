require_relative '../environment'

class ArrangementTest < ActiveSupport::TestCase
  def root_node(model)
    model.order(:id).first
  end

  def middle_node(model)
    root_node(model).children.sort_by(&:id).first
  end

  def leaf_node(model)
    model.order("id DESC").first
  end

  # Walk the tree of arranged nodes and measure the number of children and
  #   the expected ids at each depth
  def assert_tree(arranged_nodes, size_at_depth)
    return if size_at_depth.empty?

    assert_equal size_at_depth[0], arranged_nodes.size
    arranged_nodes.each do |node, children|
      assert_equal size_at_depth[1], children.size
      assert_equal node.children.sort_by(&:id), children.keys.sort_by(&:id)

      assert_tree(children, size_at_depth[1..-1])
    end
  end

  # Walk the tree of arranged nodes (which should be a single path) and measure
  #   the number of children and the expected ids at each depth
  def assert_tree_path(arranged_nodes, expected_ids)
    if expected_ids.empty?
      assert_equal 0, arranged_nodes.size
      return
    end

    assert_equal 1, arranged_nodes.size
    arranged_nodes.each do |node, children|
      assert_equal expected_ids[0], node.id

      assert_tree_path(children, expected_ids[1..-1])
    end
  end

  def test_arrangement
    AncestryTestDatabase.with_model :depth => 3, :width => 3 do |model, roots|
      assert_tree model.arrange, [3, 3, 3, 0]
    end
  end

  def test_subtree_arrange_root_node
    AncestryTestDatabase.with_model :depth => 3, :width => 2 do |model, roots|
      assert_tree root_node(model).subtree.arrange, [1, 2, 2, 0]
    end
  end

  def test_subtree_arrange_middle_node
    AncestryTestDatabase.with_model :depth => 4, :width => 2 do |model, roots|
      assert_tree middle_node(model).subtree.arrange, [1, 2, 2, 0]
    end
  end

  def test_subtree_arrange_leaf_node
    AncestryTestDatabase.with_model :depth => 3, :width => 2 do |model, roots|
      assert_tree leaf_node(model).subtree.arrange, [1, 0]
    end
  end

  def test_descendants_arrange_root_node
    AncestryTestDatabase.with_model :depth => 3, :width => 2 do |model, roots|
      assert_tree root_node(model).descendants.arrange, [2, 2, 0]
    end
  end

  def test_descendants_arrange_middle_node
    AncestryTestDatabase.with_model :depth => 4, :width => 2 do |model, roots|
      assert_tree middle_node(model).descendants.arrange, [2, 2, 0]
    end
  end

  def test_descendants_arrange_leaf_node
    AncestryTestDatabase.with_model :depth => 3, :width => 2 do |model, roots|
      assert_tree leaf_node(model).descendants.arrange, [0]
    end
  end

  def test_path_arrange_root_node
    AncestryTestDatabase.with_model :depth => 3, :width => 2 do |model, roots|
      test_node = root_node(model)
      assert_tree_path test_node.path.arrange, test_node.path_ids
    end
  end

  def test_path_arrange_middle_node
    AncestryTestDatabase.with_model :depth => 3, :width => 2 do |model, roots|
      test_node = middle_node(model)
      assert_tree_path test_node.path.arrange, test_node.path_ids
    end
  end

  def test_path_arrange_leaf_node
    AncestryTestDatabase.with_model :depth => 3, :width => 2 do |model, roots|
      test_node = leaf_node(model)
      assert_tree_path test_node.path.arrange, test_node.path_ids
    end
  end

  def test_ancestors_arrange_root_node
    AncestryTestDatabase.with_model :depth => 3, :width => 2 do |model, roots|
      test_node = root_node(model)
      assert_tree_path test_node.ancestors.arrange, test_node.ancestor_ids
    end
  end

  def test_ancestors_arrange_middle_node
    AncestryTestDatabase.with_model :depth => 3, :width => 2 do |model, roots|
      test_node = middle_node(model)
      assert_tree_path test_node.ancestors.arrange, test_node.ancestor_ids
    end
  end

  def test_ancestors_arrange_leaf_node
    AncestryTestDatabase.with_model :depth => 3, :width => 2 do |model, roots|
      test_node = leaf_node(model)
      assert_tree_path test_node.ancestors.arrange, test_node.ancestor_ids
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
          "children"=>
           [{"id"=>6},
            {"id"=>5}]},
         {
          "id"=>1,
          "children"=>
           [{"id"=>3},
            {"id"=>2}]}]
      result = model.arrange_serializable(order: "id desc") do |parent, children|
        out = {}
        out["id"] = parent.id
        out["children"] = children if children.count > 1
        out
      end
      assert_equal result, expected_result
    end
  end

  def test_arrange_order_option
    AncestryTestDatabase.with_model :width => 3, :depth => 3 do |model, roots|
      descending_nodes_lvl0 = model.arrange :order => 'id desc'
      ascending_nodes_lvl0 = model.arrange :order => 'id asc'

      descending_nodes_lvl0.keys.zip(ascending_nodes_lvl0.keys.reverse).each do |descending_node1, ascending_node1|
        assert_equal descending_node1, ascending_node1
        descending_nodes_lvl1 = descending_nodes_lvl0[descending_node1]
        ascending_nodes_lvl1 = ascending_nodes_lvl0[ascending_node1]
        descending_nodes_lvl1.keys.zip(ascending_nodes_lvl1.keys.reverse).each do |descending_node2, ascending_node2|
          assert_equal descending_node2, ascending_node2
          descending_nodes_lvl2 = descending_nodes_lvl1[descending_node2]
          ascending_nodes_lvl2 = ascending_nodes_lvl1[ascending_node2]
          descending_nodes_lvl2.keys.zip(ascending_nodes_lvl2.keys.reverse).each do |descending_node3, ascending_node3|
            assert_equal descending_node3, ascending_node3
            descending_nodes_lvl3 = descending_nodes_lvl2[descending_node3]
            ascending_nodes_lvl3 = ascending_nodes_lvl2[ascending_node3]
            descending_nodes_lvl3.keys.zip(ascending_nodes_lvl3.keys.reverse).each do |descending_node4, ascending_node4|
              assert_equal descending_node4, ascending_node4
            end
          end
        end
      end
    end
  end

  def test_arrangement_nesting
    AncestryTestDatabase.with_model :extra_columns => {:name => :string} do |model|
      model.send :default_scope, lambda { model.order('name') }

      model.create!(:name => 'Linux').children.create! :name => 'Debian'

      assert_equal 1, model.arrange.count
    end
  end
end
