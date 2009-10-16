ActiveRecord::Schema.define(:version => 0) do 
  create_table :test_nodes, :force => true do |t|
    t.string :ancestry
  end 

  create_table :alternative_test_nodes, :force => true do |t|
    t.string :alternative_ancestry
  end 
end