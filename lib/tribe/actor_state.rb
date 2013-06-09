module Tribe
  class ActorState
    attr_accessor :dedicated
    attr_accessor :mailbox
    attr_accessor :registry
    attr_accessor :scheduler
    attr_accessor :timers
    attr_accessor :name
    attr_accessor :pool
    attr_accessor :active_event
    attr_accessor :parent
    attr_accessor :children
    attr_accessor :exception
  end
end
