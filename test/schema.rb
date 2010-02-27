ActiveRecord::Schema.define(:version => 0) do 
  create_table :test_nodes, :force => true do |t|
    t.string :ancestry
    t.integer :depth_cache
    t.string :type
  end 

  create_table :alternative_test_nodes, :force => true do |t|
    t.string :alternative_ancestry
  end 

  create_table :other_test_nodes, :force => true do |t|
    t.string :ancestry
  end
  
  create_table :parent_id_test_nodes, :force => true do |t|
    t.string :ancestry
    t.integer :parent_id
  end

  create_table :acts_as_tree_test_nodes, :force => true do |t|
    t.string :ancestry
  end
end