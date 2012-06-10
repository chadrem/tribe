module Tribe
  class Registry
    def initialize
      @lock = Mutex.new

      @actors_by_oid = {}
      @actors_by_name = {}
    end

    def register(actor)
      @lock.synchronize do
        @actors_by_oid[actor.object_id] = actor

        if actor.name
          if @actors_by_name[actor.name]
            raise "Actor already exists. name=#{actor.name}"
          else
            @actors_by_name[actor.name] = actor
          end
        end
      end

      true
    end

    def unregister(actor)
      @lock.synchronize do
        @actors_by_oid.delete(actor.object_id)

        if actor.name
          @actors_by_name.delete(actor.name)
        end
      end

      true
    end

    def [](val)
      @lock.synchronize do
        return @actors_by_name[val]
      end
    end
  end
end
