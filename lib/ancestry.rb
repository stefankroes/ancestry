require_relative 'ancestry/version'
require_relative 'ancestry/class_methods'
require_relative 'ancestry/instance_methods'
require_relative 'ancestry/exceptions'
require_relative 'ancestry/has_ancestry'
require_relative 'ancestry/materialized_path'
require_relative 'ancestry/materialized_path_pg'

I18n.load_path += Dir[File.join(File.expand_path(File.dirname(__FILE__)),
                                 'ancestry', 'locales', '*.{rb,yml}').to_s]

module Ancestry
  @@default_update_strategy = :ruby

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
end
