module Tribe
  class Actor
    include Tribe::Actable

    def initialize(options = {})
      init_actable(options)
    end
  end
end
