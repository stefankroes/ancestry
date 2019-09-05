module Ancestry
  module MaterializedPath
    BEFORE_LAST_SAVE_SUFFIX = ActiveRecord::VERSION::STRING >= '5.1.0' ? '_before_last_save' : '_was'
    IN_DATABASE_SUFFIX = ActiveRecord::VERSION::STRING >= '5.1.0' ? '_in_database' : '_was'

    def self.extended(base)
      base.validates_format_of base.ancestry_column, :with => Ancestry::ANCESTRY_PATTERN, :allow_nil => true
      base.send(:include, InstanceMethods)
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

    # indirect = anyone who is a descendant, but not a child
    def indirect_conditions(object)
      t = arel_table
      node = to_node(object)
      # rails has case sensitive matching.
      if ActiveRecord::VERSION::MAJOR >= 5
        t[ancestry_column].matches("#{node.child_ancestry}/%", nil, true)
      else
        t[ancestry_column].matches("#{node.child_ancestry}/%")
      end
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
      descendant_conditions(node).or(t[primary_key].eq(node.id))
    end

    def sibling_conditions(object)
      t = arel_table
      node = to_node(object)
      t[ancestry_column].eq(node[ancestry_column])
    end

    module InstanceMethods
      ANCESTRY_DELIMITER='/'.freeze

      # Validates the ancestry, but can also be applied if validation is bypassed to determine if children should be affected
      def sane_ancestry?
        ancestry_value = read_attribute(self.ancestry_base_class.ancestry_column)
        ancestry_value.nil? || (ancestry_value.to_s =~ Ancestry::ANCESTRY_PATTERN && !ancestor_ids.include?(self.id))
      end

      # optimization - better to go directly to column and avoid parsing
      def ancestors?
        read_attribute(self.ancestry_base_class.ancestry_column).present?
      end
      alias :has_parent? :ancestors?

      def ancestor_ids=(value)
        if value.present?
          write_attribute(self.ancestry_base_class.ancestry_column, value.join("/"))
        else
          write_attribute(self.ancestry_base_class.ancestry_column, nil)
        end
      end

      def ancestor_ids
        parse_ancestry_column(read_attribute(self.ancestry_base_class.ancestry_column))
      end

      # deprecated - probably don't want to use anymore
      def ancestor_ids_was
        parse_ancestry_column(send("#{self.ancestry_base_class.ancestry_column}_was"))
      end

      def ancestor_ids_before_last_save
        parse_ancestry_column(send("#{self.ancestry_base_class.ancestry_column}#{BEFORE_LAST_SAVE_SUFFIX}"))
      end

      # deprecate
      def ancestor_was_conditions
        {primary_key_with_table => ancestor_ids_before_last_save}
      end

      def parent_id_before_last_save
        ancestry_was = send("#{self.ancestry_base_class.ancestry_column}#{BEFORE_LAST_SAVE_SUFFIX}")
        return unless ancestry_was.present?

        parse_ancestry_column(ancestry_was).last
      end

      # optimization - better to go directly to column and avoid parsing
      def sibling_of?(node)
        self.read_attribute(self.ancestry_base_class.ancestry_column) == node.read_attribute(self.ancestry_base_class.ancestry_column)
      end

      # private (public so class methods can find it)
      # The ancestry value for this record's children (before save)
      # This is technically child_ancestry_was
      def child_ancestry
        # New records cannot have children
        raise Ancestry::AncestryException.new('No child ancestry for new record. Save record before performing tree operations.') if new_record?
        # if self.send("#{self.ancestry_base_class.ancestry_column}#{IN_DATABASE_SUFFIX}").blank?
        #   id.to_s
        # else
        #   "#{self.send "#{self.ancestry_base_class.ancestry_column}#{IN_DATABASE_SUFFIX}"}/#{id}"
        # end
        path_ids_was.join(ANCESTRY_DELIMITER)
      end

      private

      def parse_ancestry_column obj
        return [] unless obj
        obj_ids = obj.split(ANCESTRY_DELIMITER)
        self.class.primary_key_is_an_integer? ? obj_ids.map!(&:to_i) : obj_ids
      end
    end
  end
end
