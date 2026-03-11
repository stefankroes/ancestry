# frozen_string_literal: true

require_relative '../environment'

class AssociationsTest < ActiveSupport::TestCase
  # --- belongs_to :parent ---

  def test_parent_association_defined
    AncestryTestDatabase.with_model(parent: true) do |model|
      assert model.reflect_on_association(:parent), "belongs_to :parent should be defined"
      assert_equal :belongs_to, model.reflect_on_association(:parent).macro
    end
  end

  def test_parent_association_not_defined_without_parent_cache
    AncestryTestDatabase.with_model do |model|
      refute model.reflect_on_association(:parent), "belongs_to :parent should not be defined without parent: true"
    end
  end

  def test_associations_not_defined_with_associations_false
    AncestryTestDatabase.with_model(parent: true, root: true, associations: false) do |model|
      refute model.reflect_on_association(:parent), "no parent association with associations: false"
      refute model.reflect_on_association(:children), "no children association with associations: false"
      refute model.reflect_on_association(:root), "no root association with associations: false"
    end
  end

  def test_parent_association_with_custom_column
    AncestryTestDatabase.with_model(parent: 'my_parent_id') do |model|
      assert model.reflect_on_association(:parent), "belongs_to :parent with custom column"
      assert model.reflect_on_association(:children), "has_many :children with custom column"
      assert_equal 'my_parent_id', model.reflect_on_association(:parent).foreign_key

      root = model.create!
      child = model.create!(parent: root)
      child.reload

      assert_equal root, child.parent
      assert_equal root.id, child.read_attribute(:my_parent_id)
      assert_equal [child], root.children.to_a
    end
  end

  def test_parent_association_defined_with_virtual_parent
    return unless AncestryTestDatabase.virtual_columns?

    AncestryTestDatabase.with_model(parent: :virtual) do |model|
      assert model.reflect_on_association(:parent), "belongs_to :parent with parent: :virtual"
      assert model.reflect_on_association(:children), "has_many :children with parent: :virtual"
      assert_equal 'parent_id', model.reflect_on_association(:parent).foreign_key
    end
  end

  def test_virtual_parent_includes
    return unless AncestryTestDatabase.virtual_columns?

    AncestryTestDatabase.with_model(parent: :virtual) do |model|
      root = model.create!
      child = model.create!(parent: root)

      children = model.where(id: child.id).includes(:parent).to_a
      assert children.first.association(:parent).loaded?, "parent should be preloaded"
      assert_equal root, children.first.parent
    end
  end

  def test_virtual_parent_includes_children
    return unless AncestryTestDatabase.virtual_columns?

    AncestryTestDatabase.with_model(parent: :virtual) do |model|
      root = model.create!
      child1 = model.create!(parent: root)
      child2 = model.create!(parent: root)

      roots = model.where(id: root.id).includes(:children).to_a
      assert roots.first.association(:children).loaded?, "children should be preloaded"
      assert_equal [child1.id, child2.id].sort, roots.first.children.map(&:id).sort
    end
  end

  def test_virtual_parent_assign_and_move
    return if !AncestryTestDatabase.virtual_columns? || AncestryTestDatabase.mysql?

    AncestryTestDatabase.with_model(parent: :virtual, root: :virtual) do |model|
      root1 = model.create!
      root2 = model.create!
      child = model.create!(parent: root1)
      child.reload

      assert_equal root1, child.parent
      assert_equal root1.id, child.parent_id
      assert_equal root1, child.root
      assert_equal root1.id, child.root_id

      # move to new parent — check in-memory values before save
      child.parent = root2
      assert_equal root2.id, child.parent_id
      assert_equal root2, child.parent
      assert_equal root2.id, child.root_id
      assert_equal root2, child.root

      # save and reload — check DB-computed virtual columns
      child.save!
      child.reload
      assert_equal root2, child.parent
      assert_equal root2.id, child.parent_id
      assert_equal root2.id, child.read_attribute(:parent_id)
      assert_equal root2, child.root
      assert_equal root2.id, child.root_id
      assert_equal root2.id, child.read_attribute(:root_id)
    end
  end

  def test_parent_returns_correct_parent
    AncestryTestDatabase.with_model(parent: true) do |model|
      root = model.create!
      child = model.create!(parent: root)
      child.reload

      assert_equal root, child.parent
      assert_nil root.parent
    end
  end

  def test_parent_after_move
    AncestryTestDatabase.with_model(parent: true) do |model|
      root1 = model.create!
      root2 = model.create!
      child = model.create!(parent: root1)
      child.reload

      child.parent = root2
      assert_equal root2, child.parent, "parent should reflect the new parent before save"
      assert_equal root2.id, child.parent_id

      child.save!
      child.reload
      assert_equal root2, child.parent
      assert_equal root2.id, child.read_attribute(:parent_id)
    end
  end

  def test_parent_after_ancestor_ids_set
    AncestryTestDatabase.with_model(parent: true) do |model|
      root1 = model.create!
      root2 = model.create!
      child = model.create!(parent: root1)
      child.reload

      child.ancestor_ids = [root2.id]
      assert_equal root2.id, child.parent_id
      assert_equal root2.id, child.read_attribute(:parent_id),
        "real parent_id column should be synced immediately"
      assert_equal root2, child.parent
    end
  end

  def test_parent_association_cache_populated_on_set
    AncestryTestDatabase.with_model(parent: true) do |model|
      root = model.create!
      child = model.new

      child.parent = root
      assert child.association(:parent).loaded?,
        "association cache should be populated after parent="
      assert_equal root, child.association(:parent).target
    end
  end

  def test_parent_association_cache_reset_on_ancestor_ids
    AncestryTestDatabase.with_model(parent: true) do |model|
      root1 = model.create!
      root2 = model.create!
      child = model.create!(parent: root1)
      child.reload

      # Load and cache the association
      assert_equal root1, child.parent

      # Change via ancestor_ids=
      child.ancestor_ids = [root2.id]

      # Cache should be reset, next access should return new parent
      assert_equal root2, child.parent
    end
  end

  def test_includes_parent
    AncestryTestDatabase.with_model(parent: true) do |model|
      root = model.create!
      child1 = model.create!(parent: root)
      child2 = model.create!(parent: root)

      children = model.where(id: [child1.id, child2.id]).includes(:parent).to_a
      assert children.all? { |c| c.association(:parent).loaded? },
        "parent should be preloaded"
      assert_equal root, children.first.parent
      assert_equal root, children.last.parent
    end
  end

  # --- has_many :children ---

  def test_children_association_defined
    AncestryTestDatabase.with_model(parent: true) do |model|
      assert model.reflect_on_association(:children), "has_many :children should be defined"
      assert_equal :has_many, model.reflect_on_association(:children).macro
    end
  end

  def test_children_association_not_defined_without_parent_cache
    AncestryTestDatabase.with_model do |model|
      refute model.reflect_on_association(:children), "has_many :children should not be defined without parent: true"
    end
  end

  def test_children_returns_correct_children
    AncestryTestDatabase.with_model(parent: true) do |model|
      root = model.create!
      child1 = model.create!(parent: root)
      child2 = model.create!(parent: root)
      _grandchild = model.create!(parent: child1)

      assert_equal [child1.id, child2.id].sort, root.children.pluck(:id).sort
      assert_equal [child1.id, child2.id].sort, root.child_ids.sort
    end
  end

  def test_has_children_and_childless
    AncestryTestDatabase.with_model(parent: true) do |model|
      root = model.create!
      child = model.create!(parent: root)

      assert root.has_children?
      assert root.children?
      refute root.is_childless?
      refute root.childless?

      refute child.has_children?
      refute child.children?
      assert child.is_childless?
      assert child.childless?
    end
  end

  def test_includes_children
    AncestryTestDatabase.with_model(parent: true) do |model|
      root = model.create!
      child1 = model.create!(parent: root)
      child2 = model.create!(parent: root)

      roots = model.where(id: root.id).includes(:children).to_a
      loaded_root = roots.first
      assert loaded_root.association(:children).loaded?,
        "children should be preloaded"
      assert_equal [child1.id, child2.id].sort, loaded_root.children.map(&:id).sort
    end
  end

  # --- inverse_of ---

  def test_inverse_of_parent_children
    AncestryTestDatabase.with_model(parent: true) do |model|
      root = model.create!
      _child1 = model.create!(parent: root)
      _child2 = model.create!(parent: root)

      loaded_root = model.where(id: root.id).includes(:children).first
      loaded_child = loaded_root.children.first

      # inverse_of should return the same object
      assert_same loaded_root, loaded_child.parent,
        "inverse_of should return the same cached parent object"
    end
  end

  def test_inverse_of_children_parent
    AncestryTestDatabase.with_model(parent: true) do |model|
      root = model.create!
      child = model.create!(parent: root)

      loaded_child = model.where(id: child.id).includes(:parent).first
      loaded_parent = loaded_child.parent

      # The parent's children should include the child
      # (inverse_of wires this up)
      assert loaded_parent.association(:children).loaded? == false,
        "children not preloaded in this direction (only parent was preloaded)"
    end
  end

  # --- belongs_to :root ---

  def test_root_association_defined
    AncestryTestDatabase.with_model(root: true) do |model|
      assert model.reflect_on_association(:root), "belongs_to :root should be defined"
    end
  end

  def test_root_association_not_defined_without_root_option
    AncestryTestDatabase.with_model do |model|
      refute model.reflect_on_association(:root), "no root association without root option"
    end
  end

  def test_root_association_with_custom_column
    AncestryTestDatabase.with_model(root: 'my_root_id') do |model|
      assert model.reflect_on_association(:root), "belongs_to :root with custom column"
      assert_equal 'my_root_id', model.reflect_on_association(:root).foreign_key

      root = model.create!
      child = model.create!(parent: root)
      child.reload

      assert_equal root, child.root
      assert_equal root.id, child.read_attribute(:my_root_id)
    end
  end

  def test_root_association_defined_with_virtual_root
    return if !AncestryTestDatabase.virtual_columns? || AncestryTestDatabase.mysql?

    AncestryTestDatabase.with_model(root: :virtual) do |model|
      assert model.reflect_on_association(:root), "belongs_to :root with root: :virtual"
      assert_equal 'root_id', model.reflect_on_association(:root).foreign_key
    end
  end

  def test_virtual_root_includes
    return if !AncestryTestDatabase.virtual_columns? || AncestryTestDatabase.mysql?

    AncestryTestDatabase.with_model(root: :virtual) do |model|
      root = model.create!
      child = model.create!(parent: root)
      grandchild = model.create!(parent: child)

      nodes = model.where(id: [child.id, grandchild.id]).includes(:root).to_a
      assert nodes.all? { |n| n.association(:root).loaded? }, "root should be preloaded"
      assert nodes.all? { |n| n.root == root }
    end
  end

  def test_root_returns_self_for_root_nodes
    AncestryTestDatabase.with_model(root: true) do |model|
      root = model.create!
      assert_equal root, root.root
    end
  end

  def test_root_returns_correct_root
    AncestryTestDatabase.with_model(root: true) do |model|
      root = model.create!
      child = model.create!(parent: root)
      grandchild = model.create!(parent: child)

      assert_equal root, child.root
      assert_equal root, grandchild.root
    end
  end

  def test_root_after_move
    AncestryTestDatabase.with_model(root: true) do |model|
      root1 = model.create!
      root2 = model.create!
      child = model.create!(parent: root1)
      child.reload

      child.parent = root2
      child.save!
      child.reload
      assert_equal root2, child.root
      assert_equal root2.id, child.read_attribute(:root_id)
    end
  end

  def test_root_association_cache_reset_on_ancestor_ids
    AncestryTestDatabase.with_model(root: true) do |model|
      root1 = model.create!
      root2 = model.create!
      child = model.create!(parent: root1)
      child.reload

      # Load and cache root
      assert_equal root1, child.root

      # Change root via ancestor_ids=
      child.ancestor_ids = [root2.id]
      assert_equal root2.id, child.read_attribute(:root_id),
        "real root_id column should be synced immediately"
      assert_equal root2, child.root
    end
  end

  def test_includes_root
    AncestryTestDatabase.with_model(root: true) do |model|
      root = model.create!
      child = model.create!(parent: root)
      grandchild = model.create!(parent: child)

      nodes = model.where(id: [child.id, grandchild.id]).includes(:root).to_a
      assert nodes.all? { |n| n.association(:root).loaded? },
        "root should be preloaded"
      assert nodes.all? { |n| n.root == root }
    end
  end

  # --- combined parent + root ---

  def test_both_parent_and_root_associations
    AncestryTestDatabase.with_model(parent: true, root: true) do |model|
      assert model.reflect_on_association(:parent)
      assert model.reflect_on_association(:root)
      assert model.reflect_on_association(:children)

      root = model.create!
      child = model.create!(parent: root)
      grandchild = model.create!(parent: child)

      assert_equal child, grandchild.parent
      assert_equal root, grandchild.root
      assert_equal [child.id], root.child_ids
    end
  end

  # --- associations: false opt-out ---

  def test_associations_false_still_has_working_parent
    AncestryTestDatabase.with_model(parent: true, associations: false) do |model|
      refute model.reflect_on_association(:parent)
      refute model.reflect_on_association(:children)

      root = model.create!
      child = model.create!(parent: root)
      child.reload

      assert_equal root, child.parent
      assert_equal root.id, child.parent_id
      assert_equal [child.id], root.child_ids
    end
  end

  def test_associations_false_children_falls_back_to_scope
    AncestryTestDatabase.with_model(parent: true, associations: false) do |model|
      root = model.create!
      child = model.create!(parent: root)

      # Without association, children is the scope-delegating method
      assert_equal [child], root.children.to_a
      assert root.has_children?
      refute child.has_children?
    end
  end

  # --- combined parent + root mid-move ---

  def test_combined_parent_root_sync_on_ancestor_ids
    AncestryTestDatabase.with_model(parent: true, root: true) do |model|
      root1 = model.create!
      root2 = model.create!
      child = model.create!(parent: root1)
      child.reload

      child.ancestor_ids = [root2.id]
      assert_equal root2.id, child.read_attribute(:parent_id),
        "parent_id should be synced immediately"
      assert_equal root2.id, child.read_attribute(:root_id),
        "root_id should be synced immediately"
      assert_equal root2, child.parent
      assert_equal root2, child.root
    end
  end

  # --- existing behavior preserved ---

  def test_scope_delegating_methods_still_work
    AncestryTestDatabase.with_model(parent: true) do |model|
      root = model.create!
      child = model.create!(parent: root)
      grandchild = model.create!(parent: child)

      # These methods are NOT backed by associations — they use scope delegation
      assert_equal [root, child], grandchild.ancestors.order(:id).to_a
      assert_equal [grandchild], child.descendants.to_a
      assert_equal [root, child, grandchild], root.subtree.order(:id).to_a
    end
  end

  def test_parent_id_setter_with_association
    AncestryTestDatabase.with_model(parent: true) do |model|
      root1 = model.create!
      root2 = model.create!
      child = model.create!(parent_id: root1.id)

      child.parent_id = root2.id
      assert_equal root2, child.parent, "parent should reflect new parent_id before save"

      child.save!
      child.reload
      assert_equal root2, child.parent
      assert_equal root2.path_ids, child.ancestor_ids
    end
  end

  # --- STI ---

  def test_sti_with_parent_association
    AncestryTestDatabase.with_model(parent: true, extra_columns: {type: :string}) do |model|
      subclass = Class.new(model)
      self.class.const_set(:StiTestChild, subclass)

      begin
        root = model.create!
        child = subclass.create!(parent: root)

        assert_equal root, child.parent
        assert_includes root.children, child
      ensure
        self.class.send(:remove_const, :StiTestChild)
      end
    end
  end

end
