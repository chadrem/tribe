module Tribe
  class Event

    attr_accessor :command
    attr_accessor :data
    attr_accessor :source
    attr_accessor :future

    def initialize(command, data, source = nil)
      @command = command
      @data = data
      @source = source
    end
  end
end
