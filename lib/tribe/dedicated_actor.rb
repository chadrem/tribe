module Tribe
  class DedicatedActor < Tribe::Actor
    def initialize(options = {})
      options[:dedicated] = true

      super(options)
    end
  end
end
