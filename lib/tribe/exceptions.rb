module Tribe
  class TribeError < RuntimeError; end

  class ActorShutdownError < TribeError; end
  class ActorNameError < TribeError; end
  class ActorChildDied < TribeError; end
  class ActorParentDied < TribeError; end

  class FutureError < TribeError; end
  class FutureNoResult < TribeError; end
  class FutureTimeout < TribeError; end

  class RegistryError < TribeError; end
end
