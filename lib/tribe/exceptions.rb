module Tribe
  class ActorShutdownError < RuntimeError; end
  class ActorNameError < RuntimeError; end

  class FutureError < RuntimeError; end

  class RegistryError < RuntimeError; end
end
