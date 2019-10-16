module Ancestry
  class << self
    attr_reader :optimizer

    def optimizer= klass
      @optimizer ||= klass
    end
  end
end
