module Tribe
  class TribeError < RuntimeError; end

  class ActorShutdownError < TribeError; end
  class ActorNameError < TribeError; end
  class ActorChildDied < TribeError
    attr_accessor :exception
    attr_accessor :child
  end
  class ActorUnandledChild < TribeError
  end

  class FutureError < TribeError; end
  class FutureNoResult < TribeError; end
  class FutureTimeout < TribeError; end

  class RegistryError < TribeError; end
end
