module Tribe
  class ActorState
    attr_accessor :dedicated
    attr_accessor :mailbox
    attr_accessor :registry
    attr_accessor :scheduler
    attr_accessor :timers
    attr_accessor :name
    attr_accessor :pool
    attr_accessor :alive
    attr_accessor :event
  end
end
