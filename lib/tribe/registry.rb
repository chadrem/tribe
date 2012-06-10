module Tribe
  class Registry < Tribe::Singleton

    def initialize
      @actors_by_oid = {}
      @actors_by_name = {}
    end

    def register(actor)
      @actors_by_oid[actor.object_id] = actor

      if actor.name
        @actors_by_name[actor.name] = actor
      end
    end

    def unregister(actor)
      @actors_by_oid.delete(actor.object_id)

      if actor.name
        @actors_by_name.delete(actor.name)
      end
    end

    def [](val)
      @actors_by_name[val]
    end
  end
end
