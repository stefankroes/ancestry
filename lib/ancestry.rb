require_relative 'ancestry/class_methods'
require_relative 'ancestry/instance_methods'
require_relative 'ancestry/exceptions'
require_relative 'ancestry/has_ancestry'

module Ancestry
  ANCESTRY_PATTERN = /\A[0-9]+(\/[0-9]+)*\Z/
end