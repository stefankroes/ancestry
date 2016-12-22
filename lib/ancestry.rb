require_relative 'ancestry/class_methods'
require_relative 'ancestry/instance_methods'
require_relative 'ancestry/exceptions'
require_relative 'ancestry/has_ancestry'

module Ancestry
  ANCESTRY_PATTERN = %r{
                        \A
                        ([0-9]+(\/[0-9]+)*) #integers separated by / 
                        |                   #or a list of UUID strings separated by /
                        ((?<uuid>\p{XDigit}{8}-\p{XDigit}{4}-\p{XDigit}{4}-\p{XDigit}{4}-\p{XDigit}{12})(\/\g<uuid>)*)
                        \Z     
                     }x
end
