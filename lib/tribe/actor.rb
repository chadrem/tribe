module Tribe
  class Actor
    attr_reader :name

    def initialize(options = {})
      run_hook(:pre_init)

      @alive = true
      @process_lock = Mutex.new
      @name = options[:name].freeze

      Tribe.registry.register(self)

      run_hook(:post_init)
    end

    def method_missing(method, *args, &block)
      m = method.to_s
      bang = m[-1] == '!'

      if bang && respond_to?(m.chop!)
        tell(m, *args)
      else
        super
      end
    end

    def tell(method, *args)
      Tribe.dispatcher.send(:schedule) do
        process(:method => method, :args => args)
      end

      true
    end

    private
    def process(message)
      @process_lock.synchronize do
        begin
          send(message[:method], *message[:args]) if @alive
        rescue Exception => e
          @alive = false
        end
      end
    end

    def terminate
      @alive = false
      Tribe.registry.unregister(self)
    end

    def run_hook(hook)
      send(hook) if respond_to?(hook, true)
    end
  end
end
