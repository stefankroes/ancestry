require_relative 'ancestry/version'
require_relative 'ancestry/class_methods'
require_relative 'ancestry/instance_methods'
require_relative 'ancestry/exceptions'
require_relative 'ancestry/has_ancestry'
require_relative 'ancestry/materialized_path'
require_relative 'ancestry/materialized_path2'
require_relative 'ancestry/materialized_path_pg'

I18n.load_path += Dir[File.join(File.expand_path(File.dirname(__FILE__)),
                                 'ancestry', 'locales', '*.{rb,yml}').to_s]

module Ancestry
  @@default_update_strategy = :ruby
  @@default_ancestry_format = :materialized_path
  @@default_primary_key_format = '[0-9]+'

  # @!default_update_strategy
  #   @return [Symbol] the default strategy for updating ancestry
  #
  # The value changes the default way that ancestry is updated for associated records
  #
  #    :ruby (default and legacy value)
  #
  #        Child records will be loaded into memory and updated. callbacks will get called
  #        The callbacks of interest are those that cache values based upon the ancestry value
  #
  #    :sql (currently only valid in postgres)
  #
  #        Child records are updated in sql and callbacks will not get called.
  #        Associated records in memory will have the wrong ancestry value
  def self.default_update_strategy
    @@default_update_strategy
  end

  def self.default_update_strategy=(value)
    @@default_update_strategy = value
  end

  # @!default_ancestry_format
  #   @return [Symbol] the default strategy for updating ancestry
  #
  # The value changes the default way that ancestry is stored in the database
  #
  #    :materialized_path (default and legacy)
  #
  #        Ancestry is of the form null (for no ancestors) and 1/2/ for children
  #
  #    :materialized_path2 (preferred)
  #
  #        Ancestry is of the form '/' (for no ancestors) and '/1/2/' for children
  def self.default_ancestry_format
    @@default_ancestry_format
  end

  def self.default_ancestry_format=(value)
    @@default_ancestry_format = value
  end

  # @!default_primary_key_format
  #   @return [Symbol] the regular expression representing the primary key
  #
  # The value represents the way the id looks for validation
  #
  #    '[0-9]+' (default) for integer ids
  #    '[-A-Fa-f0-9]{36}'    for uuids (though you can find other regular expressions)
  def self.default_primary_key_format
    @@default_primary_key_format
  end

  def self.default_primary_key_format=(value)
    @@default_primary_key_format = value
  end

  # TODO: move out of here
  # used for materialized path
  class MaterializedPathString < ActiveRecord::Type::Value
    def initialize(casting: :to_i, delimiter: '/')
      @casting = casting&.to_proc
      @delimiter = delimiter
    end

    def type
      :materialized_path_string
    end

    # convert to database type
    def serialize(value)
      if value.kind_of?(Array)
        value.map(&:to_s).join(@delimiter).presence
      elsif value.kind_of?(Integer)
        value.to_s
      elsif value.nil? || value.kind_of?(String)
        value
      else
        byebug
        puts "curious type: #{value.class}"
      end
    end

    def cast(value)
      cast_value(value) #unless value.nil? (want to get rid of this - fix default value)
    end

    # called by cast (form or setter) or deserialize (database)
    def cast_value(value)
      if value.kind_of?(Array)
        super
      elsif value.nil?
        # would prefer to use default here
        # but with default, it kept thinking the field had changed when it hadn't
        super([])
      else
        #TODO: test ancestry=1
        super(value.to_s.split(@delimiter).map(&@casting))
      end
    end
  end
end
ActiveRecord::Type.register(:materialized_path_string, Ancestry::MaterializedPathString)

class ArrayPatternValidator < ActiveModel::EachValidator
  def initialize(options)
    raise ArgumentError, "Pattern unspecified, Specify using :pattern" unless options[:pattern]

    options[:pattern] = /\A#{options[:pattern].to_s}\Z/ unless options[:pattern].to_s.include?('\A')
    options[:id] = true unless options.key?(:id)
    options[:integer] = true unless options.key?(:integer)

    super
  end

  def validate_each(record, attribute, value)
    if options[:id] && value.include?(record.id)
      record.errors.add(attribute, I18n.t("ancestry.exclude_self", {:class_name => self.class.name.humanize}))
    end

    if value.any? { |v| v.to_s !~ options[:pattern] }
      record.errors.add(attribute, "illegal characters")
    end

    if options[:integer] && value.any? { |v| v < 1 }
      record.errors.add(attribute, "non positive ancestor id")
    end
  end
end
