require File.expand_path('../ancestry/class_methods', __FILE__)
require File.expand_path('../ancestry/instance_methods', __FILE__)
require File.expand_path('../ancestry/exceptions', __FILE__)
require File.expand_path('../ancestry/has_ancestry', __FILE__)

module Ancestry
  ANCESTRY_PATTERN = /\A[0-9]+(\/[0-9]+)*\Z/
end
