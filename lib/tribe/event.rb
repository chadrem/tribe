module Tribe
  class Event < Workers::Event
    attr_accessor :source
    attr_accessor :future
    attr_accessor :forwarded

    def initialize(command, data, source = nil, future = nil)
      super(command, data)

      @source = source
      @future = future
    end
  end
end
