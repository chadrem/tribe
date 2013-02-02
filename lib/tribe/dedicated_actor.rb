module Tribe
  class DedicatedActor < Tribe::Actor
    private

    def initialize(options = {})
      options[:dedicated] = true

      super(options)
    end
  end
end
