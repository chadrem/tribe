module Tribe
  class Actor
    attr_reader :name

    def initialize(options = {})
      @process_lock = Mutex.new
      @name = options[:name].freeze

      Tribe.registry.register(self)
    end

    def method_missing(method, *args, &block)
      m = method.to_s
      bang = m[-1] == '!'

      if bang && respond_to?(m.chop!)
        async(m, *args)
      else
        super
      end
    end

    def async(method, *args)
      Tribe.scheduler.schedule do
        process(:method => method, :args => args)
      end

      true
    end

    private
    def process(message)
      @process_lock.synchronize do
        send(message[:method], *message[:args])
      end
    end

    def shutdown
      Tribe.registry.unregistry(self)
    end
  end
end
