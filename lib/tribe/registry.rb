module Tribe
  class Registry
    def initialize
      @mutex = Mutex.new
      @actors_by_name = {}
      @actors_by_oid = {}
    end

    def register(actor)
      @mutex.synchronize do
        raise("Actor already exists (#{actor.name}).") if @actors_by_name.key?(actor.name)

        @actors_by_name[actor.name] = actor if actor.name
        @actors_by_oid[actor.object_id] = actor

        return nil
      end
    end

    def unregister(actor)
      @mutex.synchronize do
        @actors_by_name.delete(actor.name) if actor.name
        @actors_by_oid.delete(actor.object_id)

        return nil
      end
    end

    def [](val)
      @mutex.synchronize do
        return @actors_by_name[val]
      end
    end

    def dispose
      @mutex.synchronize do
        @actors_by_name.clear
        @actors_by_oid.clear

        return nil
      end
    end

    def inspect
      @mutex.synchronize do
        return "#<#{self.class.to_s}:0x#{(object_id << 1).to_s(16)} oid_count=#{@actors_by_oid.count}, named_count=#{@actors_by_name.count}>"
      end
    end
  end
end
