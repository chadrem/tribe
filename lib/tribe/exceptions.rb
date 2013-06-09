module Tribe
  class TribeError < RuntimeError
    attr_accessor :data
  end

  class ActorShutdownError < TribeError; end
  class ActorNameError < TribeError; end
  class ActorChildDied < TribeError; end

  class FutureError < TribeError; end
  class FutureNoResult < TribeError; end
  class FutureTimeout < TribeError; end

  class RegistryError < TribeError; end
end
