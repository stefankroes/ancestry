require File.join(File.expand_path(File.dirname(__FILE__)), 'ancestry/class_methods')
require File.join(File.expand_path(File.dirname(__FILE__)), 'ancestry/instance_methods')
require File.join(File.expand_path(File.dirname(__FILE__)), 'ancestry/exceptions')
require File.join(File.expand_path(File.dirname(__FILE__)), 'ancestry/has_ancestry')

module Ancestry
  ANCESTRY_PATTERN = /\A[0-9]+(\/[0-9]+)*\Z/
end