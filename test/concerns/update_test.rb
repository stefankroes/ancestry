require_relative '../environment'

class UpdateTest < ActiveSupport::TestCase
  def test_node_creation_in_after_commit
    AncestryTestDatabase.with_model do |model|
      children=[]
      model.instance_eval do
        attr_accessor :idx
        self.after_commit do
          children << self.children.create!(:idx => self.idx - 1) if self.idx > 0
        end
      end
      model.create!(:idx => 3)
      assert_equal [1,2,3], children.first.ancestor_ids
    end
  end
end
