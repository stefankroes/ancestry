module Ancestry
  module MaterializedPath
    def self.extended(base)
      base.validates_format_of base.ancestry_column, :with => Ancestry::ANCESTRY_PATTERN, :allow_nil => true
      base.send(:include, InstanceMethods)
      base.send(:define_concat_strategy)
    end

    def root_conditions
      arel_table[ancestry_column].eq(nil)
    end

    def ancestor_conditions(object)
      t = arel_table
      node = to_node(object)
      t[primary_key].in(node.ancestor_ids)
    end

    def path_conditions(object)
      t = arel_table
      node = to_node(object)
      t[primary_key].in(node.path_ids)
    end

    def child_conditions(object)
      t = arel_table
      node = to_node(object)
      t[ancestry_column].eq(node.child_ancestry)
    end

    def descendant_conditions(object)
      t = arel_table
      node = to_node(object)
      # rails has case sensitive matching.
      if ActiveRecord::VERSION::MAJOR >= 5
        t[ancestry_column].matches("#{node.child_ancestry}/%", nil, true).or(t[ancestry_column].eq(node.child_ancestry))
      else
        t[ancestry_column].matches("#{node.child_ancestry}/%").or(t[ancestry_column].eq(node.child_ancestry))
      end
    end

    def subtree_conditions(object)
      t = arel_table
      node = to_node(object)
      descendant_conditions(object).or(t[primary_key].eq(node.id))
    end

    def sibling_conditions(object)
      t = arel_table
      node = to_node(object)
      t[ancestry_column].eq(node[ancestry_column])
    end

    # equivalent to..
    # SELECT tables.* IN (
    #   SELECT tables.id FROM tables
    #     LEFT OUTER JOIN test_nodes children ON
    #       test_nodes.ancestry || '/' || test_nodes.id = children.ancestry (*)
    #       OR test_nodes.id = children.ancestry
    #    GROUP BY test_nodes.id HAVING COUNT(children.id) = 0
    #   )
    #
    # * this part is detabese dependent, and potentially affected by material path implementation.
    # (meaning, this should be placed in this module fur the time being)
    def leaf_conditions
      t = arel_table
      t2 = arel_table.alias('children')
      parent_path = concat_all(t[ancestry_column], path_delimitor, t[primary_key])

      t[primary_key].in(
        t.project(t[primary_key])
        .outer_join(t2)
        .on(parent_path.eq(t2[ancestry_column]).or(t[primary_key].eq(t2[ancestry_column])))
        .group(t[primary_key])
        .having(t2[primary_key].count.eq(0))
      )
    end

    private
    def path_delimitor
      if ActiveRecord::VERSION::STRING >= '4.2.0' # >= Arel 6.0.0
        Arel::Nodes.build_quoted('/')
      else
        '/'
      end
    end

    def concat_all(node1, node2, *extra_nodes)
      if extra_nodes.empty?
        concat_nodes node1, node2
      else
        concat_all concat_nodes(node1, node2), *extra_nodes
      end
    end

    def define_concat_strategy
      if ActiveRecord::VERSION::STRING >= '5.1' # >= Arel 7.1.0
        def concat_nodes(left, right)
          Arel::Nodes::Concat(left, right)
        end
      else
        if ActiveRecord::Base.connection.adapter_name.downcase == 'sqlite'
          def concat_nodes(left, right)
            Arel::Nodes::InfixOperation.new('||',left,right)
          end
        else
          def concat_nodes(left, right)
            Arel::Nodes::NamedFunction.new('concat', left, right)
          end
        end
      end
    end

    module InstanceMethods
      # Validates the ancestry, but can also be applied if validation is bypassed to determine if children should be affected
      def sane_ancestry?
        ancestry_value = read_attribute(self.ancestry_base_class.ancestry_column)
        ancestry_value.nil? || (ancestry_value.to_s =~ Ancestry::ANCESTRY_PATTERN && !ancestor_ids.include?(self.id))
      end
    end
  end
end
